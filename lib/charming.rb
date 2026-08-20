# frozen_string_literal: true

require "logger"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "cli" => "CLI",
  "ui" => "UI",
  "ansi_codes" => "ANSICodes",
  "ansi_slicer" => "ANSISlicer",
  "border_painter" => "BorderPainter",
  "render_context" => "RenderContext",
  "erb_handler" => "ErbHandler",
  "key_normalizer" => "KeyNormalizer",
  "mouse_parser" => "MouseParser",
  "tty_backend" => "TTYBackend",
  "url_resolver" => "URLResolver"
)
loader.collapse("#{__dir__}/charming/presentation")
loader.setup

module Charming
  # Base error class for all Charming-specific exceptions (used by templates, generators, runtime, etc.).
  class Error < StandardError; end

  # The current environment, read from CHARMING_ENV (default "development"). Returns an
  # EnvInquirer so callers can write `Charming.env.test?` / `Charming.env.production?`.
  def self.env
    @env ||= Internal::EnvInquirer.new(ENV["CHARMING_ENV"] || "development")
  end

  # Overrides the environment (used by tests and the CLI).
  def self.env=(value)
    @env = value.nil? ? nil : Internal::EnvInquirer.new(value.to_s)
  end

  # Entry point for running a Charming application. Instantiates a Runtime for *application* and starts
  # the event loop. *backend* defaults to TTYBackend; tests pass MemoryBackend directly via `Charming::Runtime.new`.
  def self.run(application, backend: nil)
    Runtime.new(application, backend: backend).run
  end

  # Returns the seconds-per-frame time delta for a frame rate, for initializing
  # physics primitives: `Charming::Spring.new(delta_time: Charming.fps(60))`.
  def self.fps(frames_per_second)
    1.0 / frames_per_second
  end

  # Returns the normalized key symbol for an event-like object — `event.key` when the object responds
  # to it, otherwise `event.to_sym`. Lets components treat raw strings and KeyEvent objects uniformly.
  def self.key_of(event)
    key = event.respond_to?(:key) ? event.key : event
    key.to_sym
  end

  # Returns the key signature used for controller bindings, including modifier flags.
  def self.key_signature(event)
    key = key_of(event)
    modifiers = []
    modifiers << "ctrl" if event.respond_to?(:ctrl) && event.ctrl
    modifiers << "alt" if event.respond_to?(:alt) && event.alt
    modifiers << "shift" if event.respond_to?(:shift) && event.shift

    return key if modifiers.empty?

    :"#{modifiers.join("+")}+#{key}"
  end

  # Normalizes key declarations so `control+p` and `ctrl+p` resolve to the same binding.
  def self.key_binding_name(name)
    parts = name.to_s.split("+")
    return name.to_sym if parts.size == 1

    key = parts.pop.downcase
    modifiers = parts.map do |part|
      modifier = part.downcase
      (modifier == "control") ? "ctrl" : modifier
    end
    ordered_modifiers = %w[ctrl alt shift].select { |modifier| modifiers.include?(modifier) }
    ordered_modifiers += modifiers - ordered_modifiers

    :"#{(ordered_modifiers + [key]).join("+")}"
  end
end

Charming::Templates.register ".tui.erb", Charming::Templates::ErbHandler
Charming::Templates.register ".txt.erb", Charming::Templates::ErbHandler
