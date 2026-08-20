# frozen_string_literal: true

require "forwardable"

module Charming
  module Layout
    # Pane is a leaf layout node: a single rectangle with optional border, padding, and
    # styling, containing a piece of content (a string, a View, or a block evaluated in the
    # view's context). Panes with a `name` and `behavior.focus: true` are registered as
    # focusable slots in the controller's focus ring.
    class Pane
      extend Forwardable

      attr_reader :name
      def_delegators :geometry, :width, :height, :grow,
        :min_width, :max_width, :min_height, :max_height

      # *name* is the focus slot identifier. *content* (or a *block*) is the body; *view*
      # is the view used for instance_exec when the block is given. *geometry*, *style*, and
      # *behavior* are value objects that own sizing, styling, and render-time flags.
      def initialize(name: nil, content: nil, block: nil, view: nil,
        geometry: PaneGeometry.new, style: PaneStyle.new,
        behavior: PaneBehavior.new)
        @name, @content, @block, @view = name, content, block, view
        @geometry, @style, @behavior = geometry, style, behavior
      end

      # Raises ArgumentError — panes are leaves and cannot contain layout children.
      def add_child(_node)
        raise ArgumentError, "pane cannot contain layout children"
      end

      # Returns [name] when the pane is focusable and named, otherwise [].
      def focusable_names
        (@behavior.focus && name) ? [name] : []
      end

      # Returns the mouse target represented by this pane, if it has a name.
      def mouse_targets(rect)
        return [] unless name

        [{name: name, rect: rect, inner_rect: @geometry.inset(rect)}]
      end

      # Renders the pane into *rect*, applying the configured style, border, and padding
      # around the evaluated content.
      def render(rect)
        inner = @geometry.inset(rect)
        outer_style(inner).render(rendered_content(inner))
      end

      private

      attr_reader :content, :block, :view, :geometry, :style, :behavior

      # Returns the content string for *content_rect*, optionally clipped/scrolled by an
      # embedded Viewport when *behavior.should_viewport?* is true.
      def rendered_content(content_rect)
        value = if block
          block.arity.zero? ? view.instance_exec(&block) : view.instance_exec(content_rect, &block)
        else
          content
        end
        return value.to_s unless value.respond_to?(:render)
        return value.render.to_s unless @behavior.should_viewport?

        Components::Viewport.new(content: value.render, width: content_rect.width,
          height: content_rect.height, wrap: @behavior.wrap).render.to_s
      end

      # Builds the outer style object with optional border and padding, sized to the
      # inner rect of the pane.
      def outer_style(inner)
        styled = @style.resolve(view, focused: focused?)
        styled = styled.border(@geometry.border_style) if @geometry.border
        styled = styled.padding(*@geometry.padding_values) if @geometry.padding
        styled.width(inner.width).height(inner.height)
      end

      # True when the pane is configured for focus and the view reports it as focused.
      def focused?
        @behavior.focus && name && view.focused?(name)
      end
    end
  end
end
