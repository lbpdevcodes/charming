# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Textarea is a multi-line Form field backed by a TextArea widget. The cursor offset,
      # top-visible row, and preferred vertical column are all persisted in the form's
      # per-field state so the field behaves consistently when refocused mid-edit.
      class Textarea < Field
        # *value* is the initial text. *placeholder* is shown when the value is empty.
        # *width* and *height* constrain the rendered area. All other options are forwarded
        # to Field (label, required, validate, help, theme).
        def initialize(name, value: "", placeholder: "", width: nil, height: nil, **options)
          super(name, **options)
          @initial_value = value
          @placeholder = placeholder
          @width = width
          @height = height
        end

        # Binds the field, seeds the initial value, and initializes the cursor/offset state.
        def bind(state)
          super
          state[:values][name] = @initial_value if state[:values][name].nil?
          field_state[:cursor] = state[:values][name].to_s.length unless field_state.key?(:cursor)
          field_state[:offset] ||= 0
        end

        # Forwards key events to the underlying TextArea, syncing the value, cursor, offset,
        # and preferred column back into the form state. Returns Result.handled when consumed.
        def handle_key(event)
          forward_to_text_area(:handle_key, event)
        end

        # Forwards pasted text (newlines preserved) to the underlying TextArea the same way.
        def handle_paste(event)
          forward_to_text_area(:handle_paste, event)
        end

        # Renders the field with its label on the first line, body lines indented, and
        # optional help/error lines below.
        def render(active: false)
          label_line = "#{active ? ">" : " "} #{label}:"
          label_line = theme.selected.render(label_line) if active
          [label_line, *body_lines, help_line, *error_lines].compact.join("\n")
        end

        private

        # Sends *message* to a freshly-built TextArea and, when the widget consumed the
        # event, persists the value, cursor, offset, and preferred column into form state.
        def forward_to_text_area(message, event)
          area = text_area
          return nil unless area.public_send(message, event)&.handled?

          state[:values][name] = area.value
          field_state[:cursor] = area.cursor
          field_state[:offset] = area.offset
          field_state[:preferred_column] = area.preferred_column
          Result.handled
        end

        # The default value for a freshly-bound field is the *value* passed at construction.
        def default_value
          @initial_value
        end

        # Renders the multi-line body, indenting each line by two spaces.
        def body_lines
          text_area.render.lines(chomp: true).map { |line| "  #{line}" }
        end

        # Builds a fresh TextArea each render, seeded from the current form-state value and
        # the persisted cursor/offset/preferred_column.
        def text_area
          TextArea.new(
            value: value.to_s,
            placeholder: @placeholder,
            width: @width,
            height: @height,
            cursor: field_state[:cursor],
            offset: field_state[:offset],
            preferred_column: field_state[:preferred_column]
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
