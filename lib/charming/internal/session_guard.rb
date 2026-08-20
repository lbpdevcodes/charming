# frozen_string_literal: true

require "delegate"

module Charming
  module Internal
    # SessionGuard wraps the application session hash and asserts every access happens
    # on the controller's loop thread. Controller#session returns this wrapper in
    # development and test; production gets the raw hash (a warning is logged instead
    # of a raise).
    class SessionGuard < SimpleDelegator
      def initialize(session, controller)
        super(session)
        @controller = controller
      end

      def method_missing(name, *args, &block)
        @controller.assert_loop_thread!(:session)
        super
      end

      def respond_to_missing?(name, include_private = false)
        __getobj__.respond_to?(name, include_private) || super
      end
    end
  end
end
