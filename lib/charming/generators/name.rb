# frozen_string_literal: true

module Charming
  module Generators
    # Name validates a generator resource name and exposes the conventional Ruby class-name
    # variants (singular class, controller, component) derived from it. The original input
    # must match `VALID_NAME` (lowercase, snake_case, must start with a letter).
    class Name
      # Regex matching a valid snake_case resource name: lowercase letter, then any
      # combination of lowercase letters, digits, and underscores.
      VALID_NAME = /\A[a-z][a-z0-9_]*\z/

      # The original snake_case name as supplied.
      attr_reader :snake_name

      # Raises Error when *value* doesn't match `VALID_NAME`.
      def initialize(value)
        @snake_name = value.to_s
        raise Error, "Invalid name: #{value}" unless VALID_NAME.match?(@snake_name)
      end

      # The CamelCase class name (e.g., "user" → "User").
      def class_name
        Internal::Inflections.camelize(snake_name)
      end

      # The controller class name (e.g., "user" → "UserController").
      def controller_class_name
        "#{class_name}Controller"
      end

      # The component class name (e.g., "user" → "UserComponent").
      def component_class_name
        "#{class_name}Component"
      end
    end
  end
end
