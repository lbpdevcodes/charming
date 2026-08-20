# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Multiselect is a multiple-choice Form field backed by a MultiSelectList.
      # Space toggles the highlighted option's checkbox, navigation keys move the
      # highlight, and the checked set (in option order) becomes the field's value.
      # Enter is left to the Form so it advances/submits like every other field.
      class Multiselect < Field
        # *options* is the array of selectable values. *selected_indices* pre-checks
        # options. *max_selections* caps how many can be checked (nil = unlimited).
        # *option_label* extracts the display string (default: `to_s`). All other
        # options are forwarded to Field.
        def initialize(name, options:, selected_indices: [], max_selections: nil, option_label: :to_s.to_proc, **field_options)
          super(name, **field_options)
          @options = options
          @initial_indices = selected_indices
          @max_selections = max_selections
          @option_label = option_label
        end

        # Binds the field, then ensures the persisted checked set is applied.
        def bind(state)
          super
          ensure_selection
        end

        # Forwards key events to the underlying MultiSelectList, syncing the checked
        # set and highlight cursor back into the field state. Returns Result.handled when
        # consumed; Enter (the list's Result.submitted) is left unconsumed for the Form.
        def handle_key(event)
          widget = list
          result = widget.handle_key(event)
          return nil unless result&.handled?

          save_selection(widget)
          Result.handled
        end

        private

        attr_reader :options

        # The default value is the pre-checked options, in option order.
        def default_value
          checked_options(normalized_initial_indices)
        end

        # Renders the field as "Label: choice, choice".
        def render_control
          "#{label}: #{display_value}"
        end

        # The checked options' labels joined for compact display.
        def display_value
          Array(value).map { |item| @option_label.call(item) }.join(", ")
        end

        # Builds a fresh MultiSelectList from the persisted checked set and cursor.
        def list
          MultiSelectList.new(
            items: options,
            selected_indices: field_state[:selected_indices],
            selected_index: field_state[:cursor],
            max_selections: @max_selections,
            label: @option_label,
            theme: theme
          )
        end

        # Applies the persisted checked set (or the initial one) and highlight cursor.
        def ensure_selection
          checked = field_state[:selected_indices] || normalized_initial_indices
          field_state[:selected_indices] = checked.sort
          field_state[:cursor] ||= 0
          state[:values][name] = checked_options(checked)
        end

        # Persists the widget's checked set and cursor, and the options as the value.
        def save_selection(widget)
          field_state[:selected_indices] = widget.selected_indices.sort
          field_state[:cursor] = widget.selected_index
          state[:values][name] = widget.selected_items
        end

        # The options at *indices*, in option order.
        def checked_options(indices)
          indices.sort.map { |index| options[index] }
        end

        # The initial indices, de-duplicated and clamped to the option range.
        def normalized_initial_indices
          @initial_indices.to_a.map(&:to_i).uniq.select { |index| index.between?(0, options.length - 1) }
        end

        # The per-field state hash for this field.
        def field_state
          state[:fields][name]
        end
      end
    end
  end
end
