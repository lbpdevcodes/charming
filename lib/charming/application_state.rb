# frozen_string_literal: true

require "active_model"

module Charming
  # ApplicationState is the base for session-backed TUI state. It includes
  # `ActiveModel::Model` (validation, initialisation) and `ActiveModel::Attributes` (typed attributes
  # with defaults via `attribute :name, :type, default: ...`), making it suitable for screen/form state.
  #
  # Persistence across restarts is explicit: `persist :attr_name` marks the attributes that
  # `save_session` serializes. Unmarked attributes reinitialize to their defaults on the
  # next boot — by design, not by silent accident. State classes with no `persist`
  # declarations are dropped from the session file with a deprecation warning this
  # release; at 1.0 they are dropped without warning.
  class ApplicationState
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Marks attributes that persist across restarts via `persist_session`. Only
    # JSON-safe values (strings, numbers, booleans, nil, arrays/hashes of those)
    # survive the file; others are dropped with a warning.
    def self.persist(*names)
      persisted_attribute_names.concat(names.map(&:to_sym))
    end

    # The names marked with `persist`, inherited from the superclass.
    def self.persisted_attribute_names
      @persisted_attribute_names ||= superclass.respond_to?(:persisted_attribute_names) ? superclass.persisted_attribute_names.dup : []
    end

    # True when the class marks at least one attribute with `persist`.
    def self.persisted?
      persisted_attribute_names.any?
    end
  end
end
