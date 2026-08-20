# frozen_string_literal: true

module Charming
  # Raised when a controller sets the response twice in one dispatch — render, navigate,
  # and quit each assign the response, and a second assignment would silently discard the
  # first. The message names the action, the response already set, and the one attempted.
  class DoubleRenderError < Error; end
end
