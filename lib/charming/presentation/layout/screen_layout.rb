# frozen_string_literal: true

module Charming
  module Layout
    # ScreenLayout is the root of a layout tree. It owns a single child (typically a Split
    # or Pane) rendered into the full terminal screen, and an ordered list of Overlays
    # composited on top of the rendered body.
    class ScreenLayout
      # *screen* is the Charming::Screen whose dimensions define the layout area.
      # *background* (optional) is a UI::Style applied to the empty canvas behind the body.
      def initialize(screen:, background: nil)
        @screen = screen
        @background = background
        @child = nil
        @overlays = []
      end

      # Sets the single root child. Raises ArgumentError when a child is already present.
      def add_child(node)
        raise ArgumentError, "screen_layout accepts one root layout node" if child

        @child = node
      end

      # Appends an overlay to be composited on top of the body, in registration order.
      def add_overlay(node)
        overlays << node
      end

      # Returns the focusable names from the child, or [] when no child has been added.
      def focusable_names
        child ? child.focusable_names : []
      end

      # Returns all named pane mouse targets for the full screen layout.
      def mouse_targets
        return [] unless child

        child.mouse_targets(Rect.new(x: 0, y: 0, width: screen.width, height: screen.height))
      end

      # Renders the child into the full-screen rect, then composites each overlay on top —
      # ordered by z_index (higher paints last), with registration order breaking ties.
      def render
        body = UI.place(render_child, width: screen.width, height: screen.height, background: background)

        stacked_overlays.reduce(body) do |current, overlay|
          UI.overlay(current, overlay.render, top: overlay.top, left: overlay.left)
        end
      end

      # Returns the rendered frame plus registration data (focusable pane names, mouse
      # targets) as RenderArtifacts — the pure-render counterpart to #render that views
      # use so dispatch, not rendering, commits registrations.
      def render_with_artifacts
        RenderArtifacts.new(frame: render, focus_slots: focusable_names, mouse_targets: mouse_targets)
      end

      private

      # The screen, background style, the single child, and the list of overlays.
      attr_reader :screen, :background, :child, :overlays

      # Renders the child into a full-screen Rect, or returns an empty string when no child.
      def render_child
        return "" unless child

        child.render(Rect.new(x: 0, y: 0, width: screen.width, height: screen.height))
      end

      # Overlays sorted by z_index (stable: registration order breaks ties). Overlays
      # without a z_index reader (custom nodes) sort at 0.
      def stacked_overlays
        overlays.each_with_index.sort_by do |overlay, index|
          z = overlay.respond_to?(:z_index) ? overlay.z_index.to_i : 0
          [z, index]
        end.map(&:first)
      end
    end
  end
end
