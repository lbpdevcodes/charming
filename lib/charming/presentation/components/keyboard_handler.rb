# frozen_string_literal: true

module Charming
  module Components
    # KeyboardHandler is a mixin module that provides keyboard event dispatch by mapping symbolic key names
    # to private method calls. Implementors must define a constant +KEY_ACTIONS+ as a hash where each key is
    # a symbol (e.g., :up, :down, :enter) and each value is the target method name (e.g., :move_up). Call
    # +handle_key(event)+ with any event object; it uses Charming.key_of to resolve the raw event to a symbol,
    # looks up the corresponding action in KEY_ACTIONS, sends that method on self, and returns Result.handled
    # if an action was found. Returns nil when no matching key exists.
    module KeyboardHandler
      VIM_KEYMAP = {
        up: :k,
        down: :j,
        left: :h,
        right: :l
      }.freeze

      def handle_key(event)
        key = Charming.key_of(event)
        action = key_actions[key]
        return unless action

        send(action)
        Result.handled
      end

      private

      def key_actions
        base_key_actions.merge(normalized_keymap)
      end

      def base_key_actions
        self.class.const_get(:KEY_ACTIONS)
      end

      def normalized_keymap
        resolved_keymap.each_with_object({}) do |(action_key, keys), actions|
          action = base_key_actions[action_key.to_sym]
          next unless action

          Array(keys).each { |key| actions[key.to_sym] = action }
        end
      end

      def resolved_keymap
        case @keymap
        when :vim then VIM_KEYMAP
        when nil then {}
        else @keymap
        end
      end
    end
  end
end
