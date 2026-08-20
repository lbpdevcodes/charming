# frozen_string_literal: true

module Charming
  # Shell::Sidebar is the opt-in app-shell sidebar: route listing, sidebar/content focus
  # split, j/k/enter navigation, and mouse clicks on route rows. Generated apps include it
  # in ApplicationController when generated with the sidebar layout
  # (`include Charming::Shell::Sidebar`). Controllers that want Tab-driven sidebar
  # navigation declare `focus_ring :sidebar, :content`.
  module Shell
    module Sidebar
      # Moves focus to the sidebar slot and remembers the highlighted route.
      def focus_sidebar
        focus.focus(:sidebar)
        session[:sidebar_index] ||= current_route_index
        render_default_action
      end

      # Moves focus to the content side (the inverse of `focus_sidebar`). "Content" is
      # the :content slot when the ring declares one, otherwise the first non-sidebar
      # slot — so `focus_ring :sidebar, :entries` works without a literal :content.
      def focus_content
        slot = content_slot
        focus.focus(slot) if slot
        render_default_action
      end

      # True when the sidebar slot is the current focus target.
      def sidebar_focused?
        focused?(:sidebar)
      end

      # True when focus is on the content side: any current slot other than :sidebar.
      def content_focused?
        current = focus.current
        !current.nil? && current != :sidebar
      end

      # Returns the index of the currently selected route in `sidebar_routes`, defaulting to the
      # active route when the session index is unset. Stored in the session: the sidebar cursor
      # is app-global — it should keep its position as the user moves between screens.
      def sidebar_index
        session[:sidebar_index] || current_route_index
      end

      # Returns all routes from the application's router, in registration order.
      def sidebar_routes
        application.routes.all
      end

      # True when *candidate* route matches the controller's currently active route (used to
      # highlight the current row in the sidebar).
      def current_route?(candidate)
        return candidate.controller_class == self.class && candidate.action == :show unless route

        candidate.name == route.name &&
          candidate.controller_class == route.controller_class &&
          candidate.action == route.action
      end

      private

      # Returns the index of the route that matches `current_route?`, defaulting to 0.
      def current_route_index
        sidebar_routes.index { |candidate| current_route?(candidate) } || 0
      end

      # Dispatches j/k/enter/tab/escape to sidebar movement and selection; falls through to
      # a default render for any other key.
      def dispatch_sidebar_key
        case key_name
        when :j, :down then sidebar_move(+1)
        when :k, :up then sidebar_move(-1)
        when :enter then sidebar_select
        when :escape, :tab then focus_content
        else render_default_action
        end
        response
      end

      # Mouse dispatch for the sidebar: a click on a route row selects it and navigates
      # immediately; a click elsewhere in the sidebar pane focuses the sidebar. Uses the
      # :sidebar pane's inner rect from the latest render to translate screen coordinates
      # to nav rows. Returns nil when the click missed the sidebar entirely.
      def dispatch_sidebar_mouse
        return nil unless event.respond_to?(:click?) && event.click?

        row = sidebar_row_at(event.x, event.y)
        return nil unless row

        if row.between?(0, sidebar_routes.length - 1)
          session[:sidebar_index] = row
          sidebar_select
        else
          focus.focus(:sidebar)
          render_default_action
        end
        response
      end

      # The number of rows above the first nav item inside the sidebar pane's content
      # area (the generated layout renders the app title plus a blank gap line).
      # Override in controllers whose sidebar layout differs.
      def sidebar_nav_offset
        2
      end

      # Maps screen coordinates to a nav-row index inside the :sidebar pane's inner
      # rect, or nil when the click missed the sidebar.
      def sidebar_row_at(x, y)
        target = mouse_targets.find { |candidate| candidate[:name] == :sidebar }
        return nil unless target

        inner = target.fetch(:inner_rect)
        return nil unless inner.cover?(x, y)

        y - inner.y - sidebar_nav_offset
      end

      # Moves the sidebar cursor by *delta* positions, clamped to the route list bounds.
      def sidebar_move(delta)
        count = sidebar_routes.length
        return render_default_action if count.zero?

        session[:sidebar_index] = (sidebar_index + delta).clamp(0, count - 1)
        render_default_action
      end

      # The slot focus_content targets: :content when declared, else the first
      # non-sidebar slot in the active ring.
      def content_slot
        ring = focus.ring
        return :content if ring.include?(:content)

        ring.find { |slot| slot != :sidebar }
      end

      # Selects the route currently highlighted in the sidebar and navigates to it.
      def sidebar_select
        route = sidebar_routes[sidebar_index]
        slot = content_slot
        focus.focus(slot) if slot
        route ? navigate(route.name) : render_default_action
      end
    end
  end
end
