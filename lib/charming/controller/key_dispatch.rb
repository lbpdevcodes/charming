# frozen_string_literal: true

module Charming
  class Controller
    # KeyDispatch resolves which handler claims a key event — the capture/bubble
    # ladder a browser would own in a web MVC app. Priority order:
    #
    # 1. Command palette (when open) consumes everything.
    # 2. A focused text-capturing component (TextInput, TextArea, Form, …) gets
    #    printable characters BEFORE key bindings — typing "q" into a field must
    #    insert a q, not quit the app.
    # 3. Global key bindings.
    # 4. An overlay focus scope (a pushed modal) captures all remaining keys.
    # 5. Sidebar keys (when focused), content bindings, then the focused component —
    #    which sees Tab before ring traversal so forms can do field navigation.
    #
    # Tiers differ in how they terminate: the palette, overlay, sidebar, and binding
    # tiers consume the key outright once their condition holds, while the component
    # tiers only consume it when the component reports :handled and otherwise let it
    # fall through to the next tier.
    class KeyDispatch
      def initialize(controller)
        @controller = controller
      end

      # Runs the ladder for the controller's current event. Returns the winning
      # tier's response, or nil when no tier claims the key.
      def call
        return palette_response if palette_open?
        return response if typed_text_claimed?
        return binding_response(global_action) if global_action
        return overlay_response if overlay?
        return sidebar_response if sidebar_focused?
        return binding_response(content_action) if content_action
        return response if component_or_ring_claimed?

        nil
      end

      private

      attr_reader :controller

      def palette_open?
        controller.respond_to?(:command_palette_open?) && controller.command_palette_open?
      end

      def palette_response
        controller.send(:dispatch_command_palette_key)
      end

      # True when a printable character was typed into a focused text-capturing
      # component and the component consumed it.
      def typed_text_claimed?
        controller.send(:printable_text_event?) &&
          controller.send(:focused_component_captures_text?) &&
          component_claimed?
      end

      def global_action
        controller.send(:global_key_action)
      end

      def content_action
        controller.send(:content_key_action)
      end

      def binding_response(action)
        controller.dispatch(action)
      end

      def overlay?
        controller.focus.overlay?
      end

      # An overlay consumes the key whether or not the component handled it.
      def overlay_response
        controller.component_dispatch.dispatch_to_focused_component
        response
      end

      def sidebar_focused?
        controller.respond_to?(:sidebar_focused?) && controller.sidebar_focused?
      end

      def sidebar_response
        controller.send(:dispatch_sidebar_key)
      end

      # Text-capturing components own their remaining keys — Tab included, so forms
      # do field navigation. Everything else keeps ring traversal ahead of the component.
      def component_or_ring_claimed?
        if controller.send(:focused_component_captures_text?)
          component_claimed? || ring_claimed?
        else
          ring_claimed? || component_claimed?
        end
      end

      def component_claimed?
        controller.component_dispatch.dispatch_to_focused_component == :handled
      end

      def ring_claimed?
        controller.component_dispatch.dispatch_tab_traversal == :handled
      end

      def response
        controller.send(:response)
      end
    end
  end
end
