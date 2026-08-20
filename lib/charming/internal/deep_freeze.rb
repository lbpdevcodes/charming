# frozen_string_literal: true

module Charming
  module Internal
    # DeepFreeze returns a deep-frozen copy of a value: strings, arrays, hashes, and
    # sets are duplicated (recursively) and frozen; numbers, symbols, and nil pass
    # through as-is (already immutable); anything else (IO, models, components) passes
    # through unfrozen — it has no sane freeze semantics across a thread boundary.
    # The caller's originals are never frozen.
    module DeepFreeze
      # Returns a deep-frozen copy of *value* per the rules above.
      def self.call(value)
        case value
        when Hash then value.to_h { |key, element| [call(key), call(element)] }.freeze
        when Array then value.map { |element| call(element) }.freeze
        when Set then value.map { |element| call(element) }.to_set.freeze
        when String then value.frozen? ? value : value.dup.freeze
        else value
        end
      end
    end
  end
end
