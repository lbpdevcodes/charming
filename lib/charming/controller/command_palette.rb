# frozen_string_literal: true

module Charming
  class Controller
    # Command palette helpers mixed into Controller. Opens/closes the palette, builds the
    # palette from registered command bindings or theme list, and routes key/mouse events
    # through it. Supports both the standard command palette (:commands) and the theme picker
    # (:themes) via a discriminated `session[:command_palette]` state hash.
    #
    # Palette state lives in the session, not on the controller: the palette is app-global —
    # a command can navigate to another screen, and the open/closed state must survive the
    # controller swap that navigation causes.
    module CommandPalette
      # Opens the command palette populated with the controller's `command_bindings`. Pushes
      # a focus scope so subsequent keys are routed to the palette.
      def open_command_palette
        session[:command_palette] = command_palette_state(:commands)
        focus.push_scope([:command_palette], origin: :command_palette)
        render_default_action
      end

      # Closes the command palette, pops its focus scope, and renders the current action.
      def close_command_palette
        session.delete(:command_palette)
        pop_command_palette_scope
        render_default_action
      end

      # True when either the command palette or theme picker is currently open.
      def command_palette_open?
        session.key?(:command_palette)
      end

      # Returns the active CommandPalette component, or nil when the palette is closed.
      def command_palette
        build_command_palette_from_state(session[:command_palette]) if command_palette_open?
      end

      private

      # Routes the current key event to the open palette. Cancels on Escape, performs the
      # selected command on Enter, otherwise persists the palette's state and re-renders.
      def dispatch_command_palette_key
        palette = command_palette
        result = palette.handle_key(event)

        if result == :cancelled
          close_command_palette
        elsif selected_command?(result)
          perform_command(result.last)
        else
          save_command_palette_state(palette)
          render_default_action unless response
        end

        response
      end

      # Mouse dispatch for the command palette. Reserved for future use; returns nil.
      def dispatch_command_palette_mouse
        nil
      end

      # Builds a CommandPalette component from the persisted palette *state* hash, dispatching
      # to command-list or theme-list construction based on the state's `:type`.
      def build_command_palette_from_state(state)
        case state.fetch(:type)
        when :commands
          build_command_palette_with_state(self.class.command_bindings, state, height: 6)
        when :themes
          build_command_palette_with_state(theme_commands, state, placeholder: "Search themes", height: 10)
        end
      end

      # Constructs the CommandPalette widget with a *commands* list and persisted *state* hash.
      def build_command_palette_with_state(commands, state, placeholder: "Search commands", height: nil)
        Components::CommandPalette.new(
          commands: commands,
          placeholder: placeholder,
          height: height,
          value: state.fetch(:value),
          cursor: state.fetch(:cursor),
          selected_index: state.fetch(:selected_index),
          theme: theme
        )
      end

      # Initial palette state hash used when opening either palette type.
      def command_palette_state(type)
        {type: type, value: "", cursor: 0, selected_index: 0}
      end

      # Merges the in-memory palette's state back into the session hash so the search query,
      # cursor, and selected index survive across renders.
      def save_command_palette_state(palette)
        session[:command_palette] = session.fetch(:command_palette).merge(palette.state)
      end

      # True when a component result is the `[:selected, command]` array shape.
      def selected_command?(result)
        result.is_a?(Array) && result.first == :selected
      end

      # Invokes the value (proc, lambda, or method symbol) of the selected *command*, then
      # closes the palette unless the command was :quit or the user has re-opened it.
      def perform_command(command)
        current_palette_state = session[:command_palette]
        pop_command_palette_scope
        perform_command_value(command.value)
        if command.value != :quit && session[:command_palette].equal?(current_palette_state)
          session.delete(:command_palette)
        end
        render_default_action unless response&.navigate? || response&.quit?
      end

      # Returns the theme-switching commands used by the theme picker palette.
      def theme_commands
        application.class.themes.keys.map do |name|
          Components::CommandPalette::Command.new(label: theme_label(name), value: -> { use_theme(name) })
        end
      end

      # Converts a theme name symbol (e.g., :dracula_dark) to a human-readable label ("Dracula Dark").
      def theme_label(name)
        name.to_s.tr("_", "-").split("-").map(&:capitalize).join(" ")
      end

      # Pops focus scopes while the top of the stack is the command palette.
      def pop_command_palette_scope
        focus.pop_scope while focus.ring == [:command_palette]
      end

      # Invokes a palette command *value* — a proc gets instance_exec'd on self, a symbol gets sent.
      def perform_command_value(value)
        value.respond_to?(:call) ? instance_exec(&value) : send(value)
      end
    end
  end
end
