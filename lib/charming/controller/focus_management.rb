# frozen_string_literal: true

module Charming
  class Controller
    # Focus helpers mixed into Controller: lazily-allocated per-controller Focus object and
    # predicates for `focused?(:slot)` checks from views. The Focus object is keyed by controller
    # class name in the session, so it survives across controller dispatches for the same class.
    module FocusManagement
      # Returns the per-controller Focus object, defining the focus ring from class-level DSL
      # declarations on first access.
      def focus
        assert_loop_thread!(:focus)
        @focus ||= Controller::Focus.for(session, self.class).tap do |f|
          f.define(self.class.focus_ring_slots) unless self.class.focus_ring_slots.empty?
        end
      end

      # Returns true when the named *slot* is the currently focused slot in this controller's focus ring.
      def focused?(slot)
        focus.focused?(slot)
      end
    end
  end
end
