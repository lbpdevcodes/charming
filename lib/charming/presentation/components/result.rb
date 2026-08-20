# frozen_string_literal: true

module Charming
  module Components
    # Result is what an interactive component returns from `handle_key`, `handle_mouse`,
    # and `handle_paste`. `kind` is the event (:handled, :submitted, :selected,
    # :cancelled, or :changed — changed is reserved for a future `on_change` DSL);
    # `value` carries the payload for submit/select/change. The legacy return forms
    # (:handled, :cancelled, [:submitted, value], [:selected, value]) still work —
    # the dispatch collaborator normalizes them to Results with `Result.normalize`.
    Result = Data.define(:kind, :value) do
      class << self
        # The component consumed the event; nothing to dispatch.
        def handled = new(kind: :handled, value: nil)

        # The component submitted a value (Enter on the last field, Ctrl+S).
        def submitted(value) = new(kind: :submitted, value: value)

        # The component selected an item (Enter/click on a row).
        def selected(value) = new(kind: :selected, value: value)

        # The component was dismissed (Escape).
        def cancelled = new(kind: :cancelled, value: nil)

        # Reserved: the component's value changed. No controller DSL consumes it yet.
        def changed(value) = new(kind: :changed, value: value)

        # Normalizes a legacy handle_* return value to a Result. nil and unknown
        # values pass through.
        def normalize(value)
          case value
          when Result then value
          when :handled then handled
          when :cancelled then cancelled
          when Array then normalize_array(value)
          else value
          end
        end

        private

        # Normalizes the legacy two-element array forms, [:submitted, v] and
        # [:selected, v]. Unknown arrays pass through unchanged.
        def normalize_array(value)
          event, payload = value
          return submitted(payload) if event == :submitted
          return selected(payload) if event == :selected

          value
        end
      end

      # Kind predicates for the dispatch pipeline and the shell.
      def handled? = kind == :handled
      def submitted? = kind == :submitted
      def selected? = kind == :selected
      def cancelled? = kind == :cancelled
      def changed? = kind == :changed
    end
  end
end
