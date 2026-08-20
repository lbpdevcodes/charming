# frozen_string_literal: true

module Charming
  module Components
    # TabBar renders a horizontal list of tabs with one active tab, navigable with
    # left/right (h/l in vim keymap) and selectable with Enter. Mouse clicks select the
    # clicked tab.
    #
    #   TabBar.new(tabs: ["Files", "Search", "Git"], selected_index: 0)
    #
    # `handle_key` returns `Result.selected(index)` on Enter, Result.handled for
    # navigation keys, and nil otherwise.
    class TabBar < Component
      include KeyboardHandler

      # Maps navigation keys to instance methods via KeyboardHandler.
      KEY_ACTIONS = {
        left: :move_left,
        right: :move_right,
        home: :move_home,
        end: :move_end
      }.freeze

      # The tab labels and the index of the active tab.
      attr_reader :tabs, :selected_index

      # Replaces the tab labels and reclamps the active tab. Lets a memoized tab bar
      # stay fresh: keep the component in a slot and assign `bar.tabs = names` before
      # each render.
      def tabs=(new_tabs)
        @tabs = Array(new_tabs).map(&:to_s)
        @selected_index = @tabs.empty? ? 0 : selected_index.clamp(0, @tabs.length - 1)
      end

      # *tabs* is the array of tab labels. *selected_index* is the active tab (default 0).
      # *separator* spaces the tabs apart.
      def initialize(tabs:, selected_index: 0, separator: "  ", keymap: :vim, theme: nil)
        super(theme: theme)
        @tabs = Array(tabs).map(&:to_s)
        @selected_index = @tabs.empty? ? 0 : selected_index.to_i.clamp(0, @tabs.length - 1)
        @separator = separator
        @keymap = keymap
      end

      # Returns `Result.selected(index)` on Enter; navigation keys move the active tab.
      def handle_key(event)
        return nil if tabs.empty?
        return Result.selected(selected_index) if Charming.key_of(event) == :enter

        super
      end

      # Selects the clicked tab. Returns Result.handled when a tab was hit, nil otherwise.
      def handle_mouse(event)
        return nil if tabs.empty?
        return nil unless event.respond_to?(:click?) && event.click?

        index = tab_index_at_column(event.x)
        return nil unless index

        @selected_index = index
        Result.handled
      end

      # Renders the tabs on one row, the active tab in the selected style.
      def render
        tabs.each_with_index.map { |tab, index| render_tab(tab, index) }.join(@separator)
      end

      private

      # Renders a single tab label, highlighting the active one.
      def render_tab(tab, index)
        label = " #{tab} "
        (index == selected_index) ? theme.selected.render(label) : theme.muted.render(label)
      end

      # Maps a column offset to the tab whose rendered span covers it (nil between tabs).
      def tab_index_at_column(column)
        offset = 0
        tabs.each_with_index do |tab, index|
          tab_width = UI::Width.measure(" #{tab} ")
          return index if column >= offset && column < offset + tab_width

          offset += tab_width + UI::Width.measure(@separator)
        end
        nil
      end

      # Moves the active tab one position left.
      def move_left
        @selected_index -= 1 if selected_index.positive?
      end

      # Moves the active tab one position right.
      def move_right
        @selected_index += 1 if selected_index < tabs.length - 1
      end

      # Jumps to the first tab.
      def move_home
        @selected_index = 0
      end

      # Jumps to the last tab.
      def move_end
        @selected_index = tabs.length - 1
      end
    end
  end
end
