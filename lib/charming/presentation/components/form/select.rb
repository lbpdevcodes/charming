# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Select is a single-choice Form field backed by a List widget. The selected option
      # becomes the field's value; navigation keys (up/down/home/end) cycle through options
      # and Enter has no effect (selection is applied immediately on key release).
      class Select < Field
        # *options* is the array of selectable values. *selected_index* defaults to 0.
        # *option_label* is a callable used to extract the display string (default: `to_s`).
        # All other options are forwarded to Field.
        def initialize(name, options:, selected_index: 0, option_label: :to_s.to_proc, **field_options)
          super(name, **field_options)
          @options = options
          @initial_selected_index = selected_index
          @option_label = option_label
        end

        # Binds the field, then ensures the persisted selection (or initial/derived one) is applied.
        def bind(state)
          super
          ensure_selection
        end

        # Forwards key events to the underlying List, syncing the chosen option index back
        # into the field state. Returns Result.handled when consumed.
        def handle_key(event)
          selection = list
          result = selection.handle_key(event)
          return nil unless result&.handled?

          save_selection(selection.selected_index)
          Result.handled
        end

        private

        # The options array (used as the source of truth for default value and clamp).
        attr_reader :options

        # The default value is the option at the clamped initial selected index.
        def default_value
          options[clamped_initial_index]
        end

        # Renders the field as "Label: <display value>".
        def render_control
          "#{label}: #{display_value}"
        end

        # Returns the stringified value via the configured option label callable.
        def display_value
          value.nil? ? "" : @option_label.call(value)
        end

        # Builds a fresh List each render with the current options, selected index, label
        # callable, and theme.
        def list
          List.new(items: options, selected_index: selected_index, label: @option_label, theme: theme)
        end

        # Ensures the persisted selection is set, falling back to the field's initial index
        # or the current stored value.
        def ensure_selection
          if field_state.key?(:selected_index)
            save_selection(field_state[:selected_index])
          elsif state[:values].key?(name)
            save_selection(index_for(state[:values][name]) || clamped_initial_index)
          else
            save_selection(clamped_initial_index)
          end
        end

        # Persists the chosen *index* and the corresponding option as the field's value.
        def save_selection(index)
          field_state[:selected_index] = clamp_index(index)
          state[:values][name] = options[field_state[:selected_index]]
        end

        # The currently persisted selected index (or the initial index when unset).
        def selected_index
          field_state[:selected_index] || clamped_initial_index
        end

        # Clamps the initial selected index to the valid range.
        def clamped_initial_index
          clamp_index(@initial_selected_index)
        end

        # Clamps *index* to the valid range. Returns 0 when there are no options.
        def clamp_index(index)
          return 0 if options.empty?

          index.to_i.clamp(0, options.length - 1)
        end

        # Returns the index of *option* in the options array, or nil when absent.
        def index_for(option)
          options.index(option)
        end

        # Returns the per-field state hash for this field.
        def field_state
          state[:fields][name]
        end
      end
    end
  end
end
