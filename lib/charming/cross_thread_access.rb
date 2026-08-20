# frozen_string_literal: true

module Charming
  # Raised when controller machinery is called from a task executor thread. Task blocks
  # receive data in via `run_task`'s `with:` and return data out as the block value; the
  # controller, session, and components belong to the loop thread. Raised in development
  # and test; production logs a warning instead.
  class CrossThreadAccess < Error; end
end
