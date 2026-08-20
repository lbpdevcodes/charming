# frozen_string_literal: true

module Charming
  module Components
    # Modal is a centered, boxed overlay with an optional title, help line, and body content.
    # The body may be a string, View, or Component; when it responds to `render`, its output
    # is used. The result is wrapped in a UI::Style border with padding.
    #
    # When *max_body_height* is given and the body is taller, the body is windowed through a
    # Viewport: up/down (and page/home/end) keys scroll it via `handle_key`, and the current
    # scroll position is exposed as `scroll_offset` so controllers can persist it.
    class Modal < Component
      # The body's current scroll offset (only meaningful with max_body_height).
      attr_reader :scroll_offset

      # *content* is the modal body. *title* (optional) is rendered centered at the top.
      # *help* (optional) is rendered as a muted footer line. *width* is the modal's total width.
      # *max_body_height* caps the visible body rows (scrollable). *scroll_offset* restores a
      # previous scroll position. *style* overrides the default `theme.modal` style.
      def initialize(content:, title: nil, help: nil, width: 52, max_body_height: nil, scroll_offset: 0, style: nil, theme: nil)
        super(theme: theme)
        @content = content
        @title = title
        @help = help
        @width = width
        @max_body_height = max_body_height
        @scroll_offset = scroll_offset
        @style = style
      end

      # Scrolls the body when it is taller than max_body_height. Returns the Viewport's
      # Result (Result.handled when the key scrolled), or nil when the modal is not
      # scrollable (so callers can route unconsumed keys).
      def handle_key(event)
        return nil unless scrollable?

        viewport = body_viewport
        result = viewport.handle_key(event)
        @scroll_offset = viewport.offset
        result
      end

      # Renders the modal as a bordered, padded string with the title above the content
      # and the help footer below it.
      def render
        box(column(*lines, gap: 1), style: modal_style)
      end

      private

      attr_reader :content, :title, :help, :width

      # Returns the array of non-nil lines: title, content, help footer.
      def lines
        [title_line, body_content, help_line].compact
      end

      # The body: windowed through a Viewport when scrollable, otherwise rendered directly.
      def body_content
        return render_content unless scrollable?

        body_viewport.render
      end

      # True when a max body height is set and the content exceeds it.
      def scrollable?
        return false unless @max_body_height

        render_content.lines.length > @max_body_height
      end

      # A Viewport over the rendered body at the current scroll offset.
      def body_viewport
        @body_viewport ||= Viewport.new(content: render_content, height: @max_body_height, offset: @scroll_offset)
      end

      # Returns the centered title line styled with the theme's title style, when a title was given.
      def title_line
        text(title, style: theme.title.align(:center).width(title_width)) if title
      end

      # Returns the help line styled with the theme's muted style, when help was given.
      def help_line
        text(help, style: theme.muted) if help
      end

      # Returns the rendered content string (memoized), calling `render` on the body when applicable.
      def render_content
        @render_content ||= content.respond_to?(:render) ? render_component(content) : content.to_s
      end

      # Returns the modal's outer style: the user-provided style or `theme.modal` at the given width.
      def modal_style
        @style || theme.modal.width(width)
      end

      # Returns the title's display width, accounting for the modal's horizontal padding/border.
      def title_width
        [width - 8, 0].max
      end
    end
  end
end
