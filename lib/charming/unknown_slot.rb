# frozen_string_literal: true

module Charming
  # Raised when a rendered layout names a focusable pane, or an `on_*` registration
  # references a slot, that nothing declares — not a `slot` declaration, not a
  # `focus_ring` entry, not a same-named method. Raised in development and test;
  # production logs a warning. The message names the fix and lists declared slots.
  class UnknownSlot < Error; end
end
