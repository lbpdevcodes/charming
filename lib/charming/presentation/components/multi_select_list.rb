# frozen_string_literal: true

module Charming
  module Components
    # MultiSelectList is a List variant where Space toggles per-item checkmarks and
    # Enter submits the checked set. Renders `[x]` / `[ ]` prefixes.
    #
    # `handle_key` returns `[:submitted, [item, ...]]` on Enter, :handled for toggles
    # and navigation, nil otherwise. *max_selections* optionally caps how many items
    # can be checked at once.
    class MultiSelectList < List
      # The set of selected (checked) item indices.
      attr_reader :selected_indices

      # Same options as List, plus *selected_indices* (initially checked items) and
      # *max_selections* (cap on simultaneous checks; nil = unlimited).
      def initialize(items:, selected_indices: [], max_selections: nil, **options)
        super(items: items, **options)
        @selected_indices = selected_indices.to_a.map(&:to_i).uniq.select { |index| index.between?(0, items.length - 1) }
        @max_selections = max_selections
      end

      # Replaces the items, reclamps the highlight (List#items=), and drops checks
      # that fall outside the new list.
      def items=(new_items)
        super
        @selected_indices = selected_indices.select { |index| index < items.length }
      end

      # Space toggles the highlighted item, Enter submits the checked items.
      def handle_key(event)
        case Charming.key_of(event)
        when :space then toggle_current
        when :enter then [:submitted, selected_items]
        else
          # Bypass List#handle_key (its Enter means single-select); use its navigation.
          keyboard_navigation(event)
        end
      end

      # The checked items, in list order.
      def selected_items
        selected_indices.sort.map { |index| items[index] }
      end

      # Renders each visible item with a checkbox prefix; the highlighted row uses the
      # selected style.
      def render
        visible_items.each_with_index.map do |item, index|
          render_checkbox_item(item, viewport_start + index)
        end.join("\n")
      end

      private

      # Toggles the highlighted item's checkbox, respecting max_selections.
      def toggle_current
        index = selected_index
        if selected_indices.include?(index)
          selected_indices.delete(index)
        else
          return :handled if @max_selections && selected_indices.length >= @max_selections

          selected_indices << index
        end
        :handled
      end

      # Navigation via the KeyboardHandler key actions (up/down/home/end and keymap aliases).
      def keyboard_navigation(event)
        key = Charming.key_of(event)
        action = key_actions[key]
        return nil unless action

        send(action)
        :handled
      end

      # One row: checkbox, then the labeled item; highlighted row in selected style.
      def render_checkbox_item(item, index)
        checkbox = selected_indices.include?(index) ? "[x]" : "[ ]"
        rendered = "#{checkbox} #{label_for(item)}"
        (index == selected_index) ? theme.selected.render(rendered) : rendered
      end

      # The display label for *item* via the List's label callable.
      def label_for(item)
        @label.call(item)
      end
    end
  end
end
