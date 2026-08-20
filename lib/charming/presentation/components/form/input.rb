# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Input is a single-line Form field backed by a TextInput widget. The cursor position
      # is persisted in the form's per-field state so the field can be refocused mid-edit.
      class Input < Field
        # *value* is the initial text. *placeholder* is shown when the value is empty.
        # *width* optionally constrains the rendered width. All other options are forwarded
        # to Field (label, required, validate, help, theme).
        def initialize(name, value: "", placeholder: "", width: nil, **options)
          super(name, **options)
          @initial_value = value
          @placeholder = placeholder
          @width = width
        end

        # Binds the field to the form state, sets the initial value if absent, and initializes
        # the per-field cursor offset to the end of the value.
        def bind(state)
          super
          state[:values][name] = @initial_value if state[:values][name].nil?
          field_state[:cursor] = state[:values][name].to_s.length unless field_state.key?(:cursor)
        end

        # Forwards key events to the underlying TextInput, syncing the value and cursor
        # back into the form state. Returns Result.handled when the event was consumed.
        def handle_key(event)
          forward_to_input(:handle_key, event)
        end

        # Forwards pasted text to the underlying TextInput the same way.
        def handle_paste(event)
          forward_to_input(:handle_paste, event)
        end

        private

        # Sends *message* to a freshly-built TextInput and, when the widget consumed
        # the event, persists the resulting value and cursor into the form state.
        def forward_to_input(message, event)
          text_input = input
          return nil unless text_input.public_send(message, event)&.handled?

          state[:values][name] = text_input.value
          field_state[:cursor] = text_input.cursor
          Result.handled
        end

        # The default value for a freshly-bound field is the *value* passed at construction.
        def default_value
          @initial_value
        end

        # Renders the field as "Label: <text input>".
        def render_control
          "#{label}: #{input.render}"
        end

        # Builds a fresh TextInput each render, seeded from the current form-state value
        # and the persisted cursor offset.
        def input
          TextInput.new(
            value: value.to_s,
            placeholder: @placeholder,
            width: @width,
            cursor: field_state[:cursor]
          )
        end

        # Returns the per-field state hash for this field.
        def field_state
          state[:fields][name]
        end
      end
    end
  end
end
