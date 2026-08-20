# frozen_string_literal: true

module Charming
  class Controller
    # Component-dispatch helpers mixed into Controller. Forwards key events to the currently
    # focused component (the slot returned by `focus.current`) and translates component return
    # values into controller hook calls (e.g., `slot_submitted`, `slot_selected`, `slot_cancelled`).
    module ComponentDispatching
      private

      # Sends the current key event to the focused component (if it responds to `handle_key`).
      # Returns `:handled` after dispatching, or nil when no component is focused.
      def dispatch_to_focused_component
        slot = focus.current
        return nil unless slot && respond_to?(slot, true)

        component = send(slot)
        return nil unless component.respond_to?(:handle_key)

        result = component.handle_key(event)
        return nil if result.nil?

        dispatch_component_result(slot, result)
        :handled
      end

      # Translates a component `handle_key` *result* into a controller hook call. `:cancelled`
      # triggers `<slot>_cancelled`, `[:submitted, value]` triggers `<slot>_submitted(value)`,
      # `[:selected, value]` triggers `<slot>_selected(value)`. Falls back to a default render
      # when no matching hook exists.
      def dispatch_component_result(slot, result)
        action, arguments = component_result_action(slot, result)
        action ? send(action, *arguments) : render_default_action
        render_default_action unless response
      end

      # Resolves which controller hook (if any) corresponds to the *result* from a component.
      def component_result_action(slot, result)
        case result
        when :cancelled
          component_action(slot, :cancelled)
        when Array
          component_array_action(slot, result)
        end
      end

      # Handles array-shaped component results, currently `[:submitted, value]` and `[:selected, value]`.
      def component_array_action(slot, result)
        event_name, value = result
        return component_action(slot, :submitted, value) if event_name == :submitted
        return component_action(slot, :selected, value) if event_name == :selected

        nil
      end

      # Returns `[action, arguments]` for the component event in *slot* with *suffix*
      # (:submitted, :selected, or :cancelled). Resolution order: an explicit
      # `on_submit`/`on_select`/`on_cancel` registration, then the legacy
      # `<slot>_<suffix>` hook (with a one-time deprecation warning). With neither,
      # development/test raise UnhandledComponentEvent; production logs a warning and
      # returns nil, which falls back to the default render.
      def component_action(slot, suffix, *arguments)
        action = self.class.component_event_bindings[[slot.to_sym, suffix]]
        return [action, arguments] if action

        legacy_action = :"#{slot}_#{suffix}"
        if respond_to?(legacy_action, true)
          Charming.deprecate(
            "#{self.class.name || "an anonymous controller"}##{legacy_action} uses the auto-discovered hook. " \
            "Declare it explicitly: `#{component_event_dsl(suffix)} :#{slot}, :#{legacy_action}`.",
            category: :"component_event_#{self.class.name}_#{slot}_#{suffix}"
          )
          return [legacy_action, arguments]
        end

        unhandled_component_event(slot, suffix)
        nil
      end

      # Raises UnhandledComponentEvent outside production; logs a warning in production.
      def unhandled_component_event(slot, suffix)
        message = "Unhandled component event: #{self.class.name || "anonymous controller"} has no handler for " \
          ":#{slot} :#{suffix}. Declare one: `#{component_event_dsl(suffix)} :#{slot}, :your_action`."
        raise UnhandledComponentEvent, message unless Charming.env.production?

        logger.warn(message)
      end

      # The class-level DSL name that declares a handler for *suffix*.
      def component_event_dsl(suffix)
        {submitted: "on_submit", selected: "on_select", cancelled: "on_cancel"}.fetch(suffix)
      end

      # Handles Tab/Shift+Tab by cycling through the focus ring. Returns :handled after rendering.
      def dispatch_tab_traversal
        return nil unless key_name == :tab
        return nil if focus.ring.empty?

        focus.cycle(event.shift ? -1 : +1)
        render_default_action
        :handled
      end

      # Hit-tests the current mouse event against named layout panes from the latest render.
      # Clicks move focus to matching slots; components in clicked panes receive local coordinates.
      def dispatch_component_mouse
        target = mouse_target_for_event
        return nil unless target

        slot = target.fetch(:name)
        previous_focus = focus.current
        focus.focus(slot) if focusable_click?(slot)

        result = dispatch_mouse_to_target_component(slot, target)
        return response if result.nil? && previous_focus == focus.current

        result ? dispatch_component_result(slot, result) : render_default_action
        response
      end

      def mouse_target_for_event
        mouse_targets.rfind { |target| target.fetch(:rect).cover?(event.x, event.y) }
      end

      def focusable_click?(slot)
        event.respond_to?(:click?) && event.click? && focus.ring.include?(slot)
      end

      def dispatch_mouse_to_target_component(slot, target)
        return nil unless respond_to?(slot, true)

        component = send(slot)
        return nil unless component.respond_to?(:handle_mouse)

        local_event = local_mouse_event(target.fetch(:inner_rect))
        return nil unless local_event

        component.handle_mouse(local_event)
      end

      def local_mouse_event(rect)
        return nil unless rect.cover?(event.x, event.y)

        Events::MouseEvent.new(
          button: event.button,
          x: event.x - rect.x,
          y: event.y - rect.y,
          ctrl: event.ctrl,
          alt: event.alt,
          shift: event.shift
        )
      end
    end
  end
end
