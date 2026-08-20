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
          slots = resolved_focus_ring
          f.define(slots) unless slots.empty?
        end
      end

      # Returns true when the named *slot* is the currently focused slot in this controller's focus ring.
      def focused?(slot)
        focus.focused?(slot)
      end

      # Internal: registers the focusable panes from the latest render — validates each
      # name against the slot registry, then defines the layout focus scope. Called by
      # views during render; the single commit point for layout focus.
      def register_layout_focus(names)
        validate_layout_slots(names)
        focus.define_layout(names)
      end

      private

      # Raises UnknownSlot for pane names nothing declares (dev/test); logs in production.
      def validate_layout_slots(names)
        unknown = names.reject { |name| known_slot?(name) }
        return if unknown.empty?

        message = unknown_slot_message(unknown, "rendered as focusable panes")
        raise UnknownSlot, message unless Charming.env.production?

        logger.warn(message)
      end

      # Validates on_submit/on_select/on_cancel registrations once per controller
      # instance, at the first dispatch (class-definition-time checks would be
      # order-sensitive: a slot's method may be defined below the registration).
      def validate_slot_registrations_once
        return if @slot_registrations_validated

        @slot_registrations_validated = true
        unknown = self.class.component_event_bindings.keys.map(&:first).uniq.reject { |name| known_slot?(name) }
        return if unknown.empty?

        message = unknown_slot_message(unknown, "registered `on_*` handlers for undeclared slots")
        raise UnknownSlot, message unless Charming.env.production?

        logger.warn(message)
      end

      # True when *name* resolves as a slot: declared with `slot`, named in the focus
      # ring, or defined as a method (the legacy convention).
      def known_slot?(name)
        self.class.slot_definitions.key?(name.to_sym) ||
          self.class.focus_ring_slots.include?(name.to_sym) ||
          respond_to?(name, true)
      end

      # Builds the UnknownSlot message, naming the unknown slots, the fix, and the
      # declared slots.
      def unknown_slot_message(unknown, context)
        declared = self.class.slot_definitions.keys
        "#{self.class.name || "An anonymous controller"} #{context}: " \
          "#{unknown.map { |name| name.inspect }.join(", ")} — nothing declares them. " \
          "Declare each with `slot :name { ... }`, add it to `focus_ring`, or define a same-named method. " \
          "Declared slots: #{declared.empty? ? "(none)" : declared.map(&:inspect).join(", ")}."
      end

      # The ring handed to Focus: the class ring, filtered to actual components when it
      # comes from declared slots (an explicit `focus_ring` keeps component-less panes).
      def resolved_focus_ring
        ring = self.class.focus_ring_slots
        return ring if self.class.explicit_focus_ring?

        ring.select { |name| component_for(name).is_a?(Component) }
      end
    end
  end
end
