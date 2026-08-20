# frozen_string_literal: true

module Charming
  module Components
    # Viewport is a scrollable region over multi-line content. Supports keyboard scrolling
    # (up/down/left/right, page up/down, home/end) and mouse interactions (scroll wheel and
    # click-to-position). Lines are clipped with ANSI awareness via `UI::ANSISlicer` so styled
    # text is preserved across horizontal scrolls. When `wrap:` is true, long lines are wrapped
    # to the configured *width* before scrolling.
    class Viewport < Component
      include KeyboardHandler

      # Maps scroll keys to the instance methods that perform them via KeyboardHandler.
      KEY_ACTIONS = {
        up: :scroll_up,
        down: :scroll_down,
        page_up: :page_up,
        page_down: :page_down,
        home: :scroll_home,
        end: :scroll_end,
        left: :scroll_left,
        right: :scroll_right
      }.freeze

      # *content* may be a string, an array of lines, or any object responding to `render`.
      # *width* and *height* constrain the visible window; *offset* is the top-visible row
      # and *column* is the left-visible column. *wrap* enables soft-wrapping of long lines.
      # *follow* pins the viewport to the bottom of the content regardless of *offset*, so
      # callers that rebuild each event stick to new content; pair with `at_bottom?` to
      # decide whether to keep following after the user scrolls.
      def initialize(content:, width: nil, height: nil, offset: 0, column: 0, wrap: false, keymap: :vim, follow: false)
        super()
        @content = content
        @width = width
        @height = height
        @position = Position.new(offset: offset, column: column)
        @wrap = wrap
        @keymap = keymap
        position.clamp(bounds)
        position.move_to(max_offset, bounds) if follow
      end

      # Renders the visible window of content as a multi-line string.
      def render
        visible_lines.map { |line| render_line(line) }.join("\n")
      end

      # The current top-visible row.
      def offset
        @position.offset
      end

      # The current left-visible column.
      def column
        @position.column
      end

      # True when the last content row is visible. Callers persisting follow mode
      # store this after key dispatch to decide whether the next build follows.
      def at_bottom?
        offset >= max_offset
      end

      # Handles mouse events: scroll wheel adjusts the row offset, click moves the top
      # visible row to the clicked position. Returns Result.handled on success.
      def handle_mouse(event)
        return nil unless height

        if event.scroll?
          scroll_delta = (event.button_name == :scroll_up) ? -1 : 1
          position.move_to(offset + scroll_delta, bounds)
          return Result.handled
        end

        return nil unless event.click?

        clicked_row = event.y
        return nil if clicked_row < 0 || clicked_row >= viewport_height

        position.move_to(offset + clicked_row, bounds)
        Result.handled
      end

      private

      attr_reader :content, :width, :height, :position

      # Scrolls the viewport up by one row.
      def scroll_up
        position.scroll_up(bounds)
      end

      # Scrolls the viewport down by one row.
      def scroll_down
        position.scroll_down(bounds)
      end

      # Scrolls up by one viewport page.
      def page_up
        position.page_up(page_size, bounds)
      end

      # Scrolls down by one viewport page.
      def page_down
        position.page_down(page_size, bounds)
      end

      # Scrolls to the top-left of the content.
      def scroll_home
        position.home
      end

      # Scrolls to the bottom-right of the content.
      def scroll_end
        position.end_at(bounds)
      end

      # Scrolls one column left.
      def scroll_left
        position.scroll_left(bounds)
      end

      # Scrolls one column right.
      def scroll_right
        position.scroll_right(bounds)
      end

      # Returns the slice of content lines visible in the current viewport, padded to *height*.
      def visible_lines
        lines = content_lines.slice(offset, viewport_height) || []
        return lines unless height

        lines + Array.new([height - lines.length, 0].max, "")
      end

      # Renders a single line according to the configured width and wrap mode: clips to the
      # visible column window when not wrapping, otherwise wraps the line to the width.
      def render_line(line)
        line_window.render(line)
      end

      # Returns the content lines, wrapped to *width* when wrap is enabled.
      def content_lines
        content_source.lines
      end

      # Returns the visible row count (the configured *height* or the content's line count).
      def viewport_height
        height || content_lines.length
      end

      # Returns the number of rows to advance on a page up/down: at least 1, otherwise the
      # viewport height.
      def page_size
        [viewport_height, 1].max
      end

      # Returns the maximum allowed row offset (so the bottom of the content is reachable).
      def max_offset
        [content_lines.length - viewport_height, 0].max
      end

      # Returns the maximum allowed column offset. Returns 0 when wrapping is enabled or
      # when no width is configured.
      def max_column
        return 0 if wrap?
        return 0 unless width

        [content_width - width, 0].max
      end

      # Returns the maximum display width across all content lines.
      def content_width
        content_source.display_width
      end

      def bounds
        {max_offset: max_offset, max_column: max_column}
      end

      # True when soft-wrapping is enabled and a positive width is configured.
      def wrap?
        @wrap && width&.positive?
      end

      def line_window
        LineWindow.new(width: width, column: column, wrap: wrap?)
      end

      def content_source
        ContentLines.new(content: content, width: width, wrap: @wrap)
      end
    end
  end
end
