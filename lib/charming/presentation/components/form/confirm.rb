# frozen_string_literal: true

module Charming
  module Components
    class Form
      # Confirm is a boolean Form field that renders a checkbox-style control. Space toggles
      # the value; y/Right sets it to true; n/Left sets it to false. Required confirms must
      # be accepted (value == true) to pass validation.
      class Confirm < Field
        # *value* is the initial boolean state (default: false). All other options are
        # forwarded to Field.
        def initialize(name, value: false, **options)
          super(name, **options)
          @initial_value = value
        end

        # Handles the standard confirm keys: space toggles, y/right sets to true, n/left
        # sets to false, and a space character (when the event exposes `char`) also toggles.
        # Returns Result.handled when consumed, nil otherwise.
        def handle_key(event)
          case Charming.key_of(event)
          when :space
            toggle
          when :y, :right
            state[:values][name] = true
          when :n, :left
            state[:values][name] = false
          else
            return nil unless event.respond_to?(:char) && event.char == " "

            toggle
          end
          Result.handled
        end

        # Returns ["must be accepted"] when required and the value is not true, otherwise
        # the result of the base Field validation.
        def validate
          return ["must be accepted"] if required? && value != true

          super
        end

        private

        # The default value for a freshly-bound field is the *value* passed at construction.
        def default_value
          @initial_value
        end

        # Renders "[x] Label" or "[ ] Label" depending on the current value.
        def render_control
          "#{checked_marker} #{label}"
        end

        # Returns the checkbox marker string.
        def checked_marker
          value ? "[x]" : "[ ]"
        end

        # Flips the current value (true ↔ false).
        def toggle
          state[:values][name] = !value
        end
      end
    end
  end
end
