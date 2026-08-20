# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Field is the abstract base class for Form fields. Subclasses define `default_value`
      # and `render_control` (or override `render`); the base class supplies validation,
      # help-line rendering, error-line rendering, and value lookup against the form state.
      class Field < Component
        # The field's name symbol, human-readable label, optional help text, and bound state hash.
        attr_reader :name, :label, :help, :state

        # *name* is the value key (a Symbol). *label* defaults to a humanized version of *name*.
        # *required* enables a "is required" validator. *validate* is an optional callable
        # (returning nil/true → ok, false → "is invalid", Array → messages, anything else → stringified).
        # *help* is an optional muted helper line rendered under the field.
        def initialize(name, label: nil, required: false, validate: nil, help: nil, theme: nil)
          super(theme: theme)
          @name = name.to_sym
          @label = label || humanize(name)
          @required = required
          @validator = validate
          @help = help
        end

        # Binds the field to the form's *state* hash, ensuring the field's per-field state
        # and a default value are present.
        def bind(state)
          @state = state
          state[:fields][name] ||= {}
          state[:values][name] = default_value unless state[:values].key?(name)
        end

        # Subclasses that participate in Tab/Enter navigation return true. Default is true.
        def focusable?
          true
        end

        # Default key handler returns nil (no key handling). Subclasses override.
        def handle_key(_event)
          nil
        end

        # Default paste handler returns nil (paste ignored). Text fields override.
        def handle_paste(_event)
          nil
        end

        # Renders the field as a control line prefixed with ">" (active) or " " (inactive),
        # optionally followed by the help line and any error lines.
        def render(active: false)
          line = "#{active ? ">" : " "} #{render_control}"
          line = theme.selected.render(line) if active
          [line, help_line, *error_lines].compact.join("\n")
        end

        # Returns an array of validation error messages. Includes "is required" when
        # the field is required and blank, plus any messages produced by the user validator.
        def validate
          messages = []
          messages << "is required" if required? && blank?(value)
          messages.concat(validator_messages) if @validator
          messages
        end

        # The current value of this field from the bound state.
        def value
          state[:values][name]
        end

        private

        # The default value assigned to a freshly-bound field. Subclasses override.
        def default_value
          nil
        end

        # Renders the control portion (label + value). Default: "Label: <value>".
        def render_control
          "#{label}: #{value}"
        end

        # True when the field was declared with `required: true`.
        def required?
          @required
        end

        # True when *value* is nil, an empty string, or responds to `empty?` with true.
        def blank?(value)
          return true if value.nil?
          return value.strip.empty? if value.is_a?(String)

          value.respond_to?(:empty?) && value.empty?
        end

        # Normalizes the user validator's return value into an array of error message strings.
        def validator_messages
          result = @validator.call(value)
          case result
          when nil, true then []
          when false then ["is invalid"]
          when Array then result
          else [result.to_s]
          end
        end

        # The muted help line (with two-space indent) when help text was given.
        def help_line
          "  #{theme.muted.render(help)}" if help
        end

        # The list of error lines (with two-space indent) for any errors stored against this field.
        def error_lines
          Array(state[:errors][name]).map { |message| "  #{theme.warn.render(message)}" }
        end

        # Converts a snake_case symbol/string to a humanized "Capitalized" string.
        def humanize(value)
          Internal::Inflections.humanize(value)
        end
      end
    end
  end
end
