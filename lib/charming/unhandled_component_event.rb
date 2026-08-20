# frozen_string_literal: true

module Charming
  # Raised when a component emits a result (`[:submitted, value]`, `[:selected, value]`,
  # or `:cancelled`) and the controller has neither an `on_submit`/`on_select`/`on_cancel`
  # registration nor a legacy `<slot>_<event>` hook for it. Raised in development and test;
  # production logs a warning and falls back to the default render instead.
  class UnhandledComponentEvent < Error; end
end
