# frozen_string_literal: true

module Charming
  module Internal
    # A String that answers predicates about its own value:
    # `EnvInquirer.new("development").development?` → true. Replaces
    # ActiveSupport::StringInquirer for `Charming.env`.
    class EnvInquirer < String
      private

      def method_missing(name, *)
        return self == name.to_s.delete_suffix("?") if name.end_with?("?")

        super
      end

      def respond_to_missing?(name, include_private = false)
        name.end_with?("?") || super
      end
    end
  end
end
