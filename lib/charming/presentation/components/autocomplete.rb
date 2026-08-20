# frozen_string_literal: true

module Charming
  module Components
    # Autocomplete is a combobox: a TextInput with a suggestion list beneath it,
    # filtered live against the typed value. Up/down move through suggestions,
    # Enter submits the highlighted suggestion (or the free text when nothing
    # matches), Escape cancels.
    #
    #   Autocomplete.new(suggestions: ["ruby", "rails", "rspec"], value: "r")
    #
    # `handle_key` returns `[:submitted, value]` on Enter, `:cancelled` on Escape,
    # `:handled` for consumed keys, nil otherwise.
    class Autocomplete < Component
      DEFAULT_MAX_SUGGESTIONS = 6

      # The current typed value and the highlighted suggestion index.
      attr_reader :selected_index

      # *suggestions* is the full candidate list. *value*/*cursor* seed the inner
      # TextInput. *max_suggestions* caps the visible dropdown rows.
      def initialize(suggestions:, value: "", cursor: nil, placeholder: "", selected_index: 0,
        max_suggestions: DEFAULT_MAX_SUGGESTIONS, theme: nil)
        super(theme: theme)
        @suggestions = Array(suggestions).map(&:to_s)
        @input = TextInput.new(value: value, cursor: cursor, placeholder: placeholder)
        @selected_index = selected_index
        @max_suggestions = max_suggestions
        clamp_selection
      end

      # Replaces the suggestion list and reclamps the selection against the filtered
      # list. Lets a memoized autocomplete stay fresh: keep the component in a slot
      # and assign `combo.suggestions = names` before each render.
      def suggestions=(new_suggestions)
        @suggestions = Array(new_suggestions).map(&:to_s)
        clamp_selection
      end

      # The typed text.
      def value
        @input.value
      end

      # The inner input's cursor offset.
      def cursor
        @input.cursor
      end

      # The suggestions matching the current value (case-insensitive substring),
      # capped at max_suggestions. All suggestions when the value is empty.
      def filtered_suggestions
        query = value.downcase
        matches = query.empty? ? @suggestions : @suggestions.select { |s| s.downcase.include?(query) }
        matches.first(@max_suggestions)
      end

      # Free-typed characters belong to this component while it is focused.
      def captures_text?
        true
      end

      # Enter submits, Escape cancels, up/down move the highlight, everything else
      # edits the text (resetting the highlight).
      def handle_key(event)
        case Charming.key_of(event)
        when :escape then :cancelled
        when :enter then [:submitted, submission_value]
        when :up then move_selection(-1)
        when :down then move_selection(+1)
        else
          result = @input.handle_key(event)
          clamp_selection if result
          result
        end
      end

      # Forwards pasted text to the inner input and re-filters the suggestions.
      def handle_paste(event)
        result = @input.handle_paste(event)
        clamp_selection if result
        result
      end

      # Renders the input row followed by the suggestion dropdown.
      def render
        [input_line, *suggestion_lines].join("\n")
      end

      private

      # The highlighted suggestion, or the raw text when none match.
      def submission_value
        filtered_suggestions[selected_index] || value
      end

      def input_line
        @input.render
      end

      # One row per suggestion; the highlighted row in the selected style.
      def suggestion_lines
        filtered_suggestions.each_with_index.map do |suggestion, index|
          line = "  #{suggestion}"
          (index == selected_index) ? theme.selected.render(line) : theme.muted.render(line)
        end
      end

      def move_selection(delta)
        count = filtered_suggestions.length
        return :handled if count.zero?

        @selected_index = (selected_index + delta).clamp(0, count - 1)
        :handled
      end

      def clamp_selection
        max = [filtered_suggestions.length - 1, 0].max
        @selected_index = selected_index.clamp(0, max)
      end
    end
  end
end
