# frozen_string_literal: true

module Charming
  module Components
    # List is a vertically-scrollable selectable list. Supports keyboard navigation
    # (up/down/home/end, Enter to activate) and mouse click selection. When a *height* is
    # given, the list renders a fixed-height window over its items with auto-scroll
    # keeping the selected item in view.
    class List < Component
      include KeyboardHandler

      # Maps navigation key symbols to instance methods consumed by the KeyboardHandler
      # mixin: :up moves selection up, :down moves down, :home jumps to first item,
      # :end jumps to last. See Viewport#KEY_ACTIONS and Table#KEY_ACTIONS for identical pattern.
      KEY_ACTIONS = {
        up: :move_up,
        down: :move_down,
        home: :move_home,
        end: :move_end
      }.freeze

      # The currently selected index (within the filtered view) and active filter query.
      attr_reader :selected_index, :filter

      # *items* is the array of selectable objects. *selected_index* defaults to 0.
      # *height* optionally constrains the visible window; *label* is a callable that
      # extracts the display string from an item (defaults to `to_s`).
      # *keymap* selects the keybinding style (`:vim` enables h/j/k/l → left/down/up/right).
      # *filter* optionally narrows items by fuzzy-matching the label (see FuzzyMatcher);
      # navigation, rendering, and selection all operate on the filtered view.
      def initialize(items:, selected_index: 0, height: nil, label: nil, theme: nil, keymap: :vim, filter: nil)
        super(theme: theme)
        @source_items = items
        @selected_index = selected_index
        @height = height
        @label = label || :to_s.to_proc
        @keymap = keymap
        @filter = filter
        clamp_position
      end

      # The visible items: the source list narrowed by the active filter (best
      # fuzzy match first), or the full source list when no filter is set.
      def items
        return @source_items if filter.nil? || filter.to_s.empty?

        FuzzyMatcher.filter(filter, @source_items, &@label)
      end

      # Replaces the filter query (nil clears it) and reclamps the selection to
      # the narrowed view.
      def filter=(query)
        @filter = query
        clamp_position
      end

      # Replaces the source items (e.g. after the underlying data changed) and
      # reclamps the selection. Lets a memoized list stay fresh: keep the component
      # in an ivar so its selection survives, then assign `list.items = rows`
      # before each render.
      def items=(new_items)
        @source_items = new_items
        clamp_position
      end

      # Handles key events. Returns `[:selected, item]` on Enter when an item is selected;
      # otherwise delegates to the KeyboardHandler for navigation keys.
      def handle_key(event)
        return [:selected, selected_item] if Charming.key_of(event) == :enter && selected_item

        super
      end

      # Handles mouse events: a click within the visible window selects the clicked row.
      # Returns :handled on a successful click, nil otherwise.
      def handle_mouse(event)
        return nil unless @height
        return nil unless event.respond_to?(:click?) && event.click?

        clicked = event.y
        return nil if clicked.negative? || clicked >= visible_items.length

        @selected_index = viewport_start + clicked
        clamp_position
        :handled
      end

      # Returns the currently selected item, or nil when the list is empty.
      def selected_item
        items[selected_index]
      end

      # Renders the visible window of items, prefixing each with "> " (and applying the
      # selected style) or "  ".
      def render
        visible_items.each_with_index.map do |item, index|
          render_item(item, viewport_start + index)
        end.join("\n")
      end

      private

      # Moves the selection up one position.
      def move_up
        @selected_index -= 1 if selected_index.positive?
      end

      # Moves the selection down one position.
      def move_down
        @selected_index += 1 if selected_index < items.length - 1
      end

      # Moves the selection to the first item.
      def move_home
        @selected_index = 0
      end

      # Moves the selection to the last item (no-op when the list is empty).
      def move_end
        @selected_index = items.length - 1 unless items.empty?
      end

      # Returns the slice of items currently in the visible window.
      def visible_items
        items[viewport_start, viewport_height] || []
      end

      # Returns the index of the topmost visible item, computed so the selected item stays
      # in view when the list is taller than the visible window.
      def viewport_start
        return 0 unless @height

        Layout.selected_window_start(selected_index: selected_index, item_count: items.length, window_size: @height)
      end

      # Returns the number of items visible in the window (the configured *height* or the
      # total item count when no height was set).
      def viewport_height
        @height || items.length
      end

      # Renders a single item: prefix with "> " (selected) or "  " (unselected), then apply
      # the theme's selected style to the selected item's row.
      def render_item(item, index)
        prefix = (index == selected_index) ? "> " : "  "
        rendered = "#{prefix}#{@label.call(item)}"
        (index == selected_index) ? theme.selected.render(rendered) : rendered
      end

      # Resets the selection when the list is empty, otherwise clamps it to the valid range.
      def clamp_position
        @selected_index = 0 if items.empty?
        @selected_index = selected_index.clamp(0, items.length - 1) unless items.empty?
      end
    end
  end
end
