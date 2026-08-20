# frozen_string_literal: true

require "fileutils"
require "json"

module Charming
  # Application is a lightweight, Rails-inspired application base for building
  # terminal-based apps. It provides routing (via a DSL), session storage, and
  # task execution for managing async operations.
  class Application
    LOGGER_READER = Object.new.freeze
    THEME_READER = Object.new.freeze
    COALESCE_READER = Object.new.freeze

    class << self
      # Registers or returns the app's Router. Accepts an optional block to define
      # routes via DSL (screen, root). Lazily initializes a new Router per namespace.
      def routes(&block)
        @routes ||= Router.new(namespace: namespace)
        @routes.draw(&block) if block
        @routes
      end

      # Derives the module namespace from the class name — e.g., Admin::HomeController
      # yields "Admin". Mirrors Rails' engine-style namespacing.
      def namespace
        Internal::Inflections.deconstantize(name.to_s)
      end

      # Returns or sets the app logger. Defaults to a null-device logger so app and framework code
      # can safely call logging methods without writing into the terminal UI.
      def logger(value = LOGGER_READER)
        return configured_logger if value == LOGGER_READER

        @logger = value
      end

      # Returns the app's filesystem root, used to resolve relative theme and template paths.
      # Pass *path* to set it; without arguments it returns the current value (or nil if unset).
      def root(path = THEME_READER)
        return @root if path == THEME_READER

        @root = File.expand_path(path)
      end

      # Registers a named theme. Provide one of:
      # - *from:* — path to a JSON theme file relative to the app root
      # - *built_in:* — name of a bundled theme ("phosphor", "catppuccin-mocha",
      #   "catppuccin-latte", "gruvbox-dark", "nord", "tokyonight")
      # - *extends:* — name of an already-registered theme to derive from, with
      #   *overrides:* (token name → style spec) merged on top:
      #
      #     theme :dark, built_in: "tokyonight"
      #     theme :high_contrast, extends: :dark, overrides: {text: {foreground: "#ffffff"}}
      def theme(name, from: nil, built_in: nil, extends: nil, overrides: nil)
        sources = [from, built_in, extends].compact
        raise ArgumentError, "theme expects from:, built_in:, or extends:" if sources.empty?
        raise ArgumentError, "theme expects only one of from:, built_in:, or extends:" if sources.length > 1
        raise ArgumentError, "overrides: requires extends:" if overrides && !extends

        themes[name.to_sym] = if extends
          parent = themes.fetch(extends.to_sym) do
            raise ArgumentError, "unknown parent theme: #{extends.inspect} (register it before extending)"
          end
          parent.merge(overrides || {})
        elsif built_in
          UI::Theme.load_builtin(built_in)
        else
          UI::Theme.load_file(resolve_theme_path(from))
        end
      end

      # Hash of all registered themes keyed by symbol, including those inherited from superclasses.
      def themes
        @themes ||= superclass.respond_to?(:themes) ? superclass.themes.dup : {}
      end

      # Returns the default theme name, or sets it when *name* is given. When unset, falls back
      # to the first registered theme. Used by `theme_for` when no name is provided.
      def default_theme(name = THEME_READER)
        return @default_theme || themes.keys.first if name == THEME_READER

        @default_theme = name.to_sym
      end

      # Resolves a theme by *name* (or the default theme when *name* is nil). Returns the default
      # built-in theme if no name is given and no default is registered.
      def theme_for(name = nil)
        theme_name = name || default_theme
        return UI::Theme.default unless theme_name

        themes.fetch(theme_name.to_sym)
      end

      # Opts into session persistence: the session hash is serialized as JSON to *to*
      # when the app quits and reloaded on boot. Only JSON-safe values survive the
      # round-trip (hash keys come back as symbols); non-serializable entries (state
      # objects, procs) are skipped with a warning in the log.
      def persist_session(to:)
        @session_path = to
      end

      # The configured session file path, walking the superclass chain. Nil when
      # persistence is not enabled.
      def session_path
        return @session_path if instance_variable_defined?(:@session_path)
        return superclass.session_path if superclass.respond_to?(:session_path)

        nil
      end

      # When true, the runtime collapses bursts of identical key events — the flood a terminal
      # emits while a key is held (OS auto-repeat) — into a single dispatch, so holding a key
      # can't queue a backlog that keeps acting after release. Off by default: it also merges
      # intentional fast repeats of the same key (e.g. tab tab), so enable it only for
      # movement-style apps. Pass a boolean to set; call without args to read (inherited).
      def coalesce_input(value = COALESCE_READER)
        return configured_coalesce_input if value == COALESCE_READER

        @coalesce_input = value
      end

      # The mouse motion reporting mode: :drag (default) reports movement only while
      # a button is held; :all also reports buttonless hover movement. Pass a symbol
      # to set; call without args to read (inherited).
      def mouse_motion(value = COALESCE_READER)
        return configured_mouse_motion if value == COALESCE_READER
        raise ArgumentError, "mouse_motion must be :drag or :all" unless %i[drag all].include?(value)

        @mouse_motion = value
      end

      private

      def configured_logger
        return @logger if instance_variable_defined?(:@logger)
        return superclass.logger if superclass.respond_to?(:logger)

        @logger = Logger.new(File::NULL)
      end

      def configured_coalesce_input
        return @coalesce_input if instance_variable_defined?(:@coalesce_input)
        return superclass.coalesce_input if superclass.respond_to?(:coalesce_input)

        false
      end

      def configured_mouse_motion
        return @mouse_motion if instance_variable_defined?(:@mouse_motion)
        return superclass.mouse_motion if superclass.respond_to?(:mouse_motion)

        :drag
      end

      # Expands a relative theme path against the app root (or the current working directory
      # when no root is configured). Returns *path* unchanged when it is already absolute.
      def resolve_theme_path(path)
        return path if File.absolute_path?(path)

        File.expand_path(path, root || Dir.pwd)
      end
    end

    attr_accessor :logger, :task_executor
    attr_writer :timer_control

    # The runtime-injected timer control used by `Controller#start_timer` and
    # friends. Defaults to a null object so controllers work outside a Runtime.
    def timer_control
      @timer_control ||= Internal::TimerControl::Null.new
    end
    attr_reader :session

    # Initializes the session hash for per-request state storage, restoring a
    # previously persisted session when `persist_session` is configured.
    def initialize
      @logger = self.class.logger
      @session = load_session
    end

    # Serializes the session to the configured `persist_session` path. Entries that
    # don't survive a JSON round-trip (state objects, procs, focus scopes) are skipped.
    # No-op when persistence isn't configured. Called by the Runtime on exit.
    def save_session
      path = self.class.session_path
      return unless path

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(serializable_session))
    rescue => e
      logger.warn("session not saved: #{e.class}: #{e.message}")
    end

    # Delegates to the class-level Router, providing instance access to route definitions.
    def routes
      self.class.routes
    end

    def theme
      self.class.theme_for(session[:theme])
    end

    def use_theme(name)
      self.class.theme_for(name)
      session[:theme] = name.to_sym
    end

    # Whether the runtime should coalesce held-key auto-repeat for this app (see the class-level
    # `coalesce_input` DSL). Read by the Runtime at startup.
    def coalesce_input?
      self.class.coalesce_input == true
    end

    # The mouse motion reporting mode for this app (see the class-level `mouse_motion`
    # DSL). Read by the Runtime at startup.
    def mouse_motion
      self.class.mouse_motion
    end

    private

    # Loads the persisted session JSON (symbolizing keys), or {} when absent/invalid.
    def load_session
      path = self.class.session_path
      return {} unless path && File.exist?(path)

      JSON.parse(File.read(path), symbolize_names: true)
    rescue JSON::ParserError => e
      logger.warn("session not restored: #{e.message}")
      {}
    end

    # Framework-internal session keys that must not be persisted: their values carry
    # symbols in *values* (which JSON round-trips into strings, corrupting focus rings
    # and palette state) and they describe transient UI state anyway.
    INTERNAL_SESSION_KEYS = %i[focus_state mouse_targets command_palette].freeze

    # The subset of session entries that survive a JSON round-trip: nil, booleans,
    # numbers, strings, symbols, and arrays/hashes of those. State objects, procs,
    # framework-internal keys, and other rich values are skipped (hash keys come back
    # as symbols via symbolize_names; symbol *values* come back as strings).
    def serializable_session
      session.except(*INTERNAL_SESSION_KEYS).select { |_key, value| json_safe?(value) }
    end

    def json_safe?(value)
      case value
      when nil, true, false, String, Symbol, Integer, Float
        true
      when Array
        value.all? { |item| json_safe?(item) }
      when Hash
        value.all? { |key, item| (key.is_a?(String) || key.is_a?(Symbol)) && json_safe?(item) }
      else
        false
      end
    end
  end
end
