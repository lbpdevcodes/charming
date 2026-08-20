# frozen_string_literal: true

module Charming
  module Components
    # Form is a multi-field form component with built-in focus traversal, validation, and
    # submit/cancel handling. Fields are produced by `Form::Builder` (see `controller.form`)
    # and bound to a per-form mutable state hash. Tab/Shift+Tab cycles focus through
    # focusable fields, Enter advances to the next field (or submits on the last), Escape
    # cancels, and Ctrl+S submits from any field.
    #
    # Exception: inside a Textarea field, Enter inserts a newline (it's a text editor) —
    # leave it with Tab and submit with Ctrl+S, matching charm.sh's huh behavior.
    class Form < Component
      # The list of field objects and the mutable state hash the form is bound to.
      attr_reader :fields, :state

      # *fields* is the array of form field objects. *state* is a hash for storing field
      # values/errors and the current focus index; usually `session[:forms][form_name]`.
      def initialize(fields:, state: nil, theme: nil)
        super(theme: theme)
        @fields = fields
        @state = normalize_state(state || {})
        bind_fields
        clamp_focus
      end

      # Handles key events: Escape cancels, Ctrl+S submits, Tab cycles focus, Enter advances
      # or submits, and unhandled keys are passed to the focused field.
      def handle_key(event)
        key = Charming.key_of(event)
        return Result.cancelled if key == :escape
        return submit if submit_shortcut?(event)
        return move_focus(tab_direction(event)) if key == :tab

        result = handle_current_field(event)
        return result if result

        advance_or_submit if key == :enter
      end

      # Forwards pasted text to the currently focused field. Text fields insert it
      # at their cursor; other fields ignore it.
      def handle_paste(event)
        current_field&.handle_paste(event)
      end

      # Forms accept free-typed text (their input/textarea fields do), so printable
      # characters route here before global/content key bindings.
      def captures_text?
        true
      end

      # Returns a hash of `{field_name => value}` for the current field values.
      def values
        state[:values]
      end

      # Renders each field on its own line, marking the active field with `active: true`.
      def render
        fields.each_with_index.map do |field, index|
          field.render(active: index == state[:focus_index])
        end.join("\n")
      end

      private

      # Ensures the state hash has all the required sub-keys: :values, :fields, :errors, and
      # a sensible :focus_index default.
      def normalize_state(value)
        value[:values] ||= {}
        value[:fields] ||= {}
        value[:errors] ||= {}
        value[:focus_index] ||= first_focusable_index || 0
        value
      end

      # Binds each field to the state hash so field updates write back into `state[:values]`.
      def bind_fields
        fields.each { |field| field.bind(state) }
      end

      # Forwards *event* to the currently focused field and returns its result.
      def handle_current_field(event)
        current_field&.handle_key(event)
      end

      # Returns -1 for Shift+Tab (backward), +1 for plain Tab (forward).
      def tab_direction(event)
        return -1 if event.respond_to?(:shift) && event.shift

        +1
      end

      # True when the event is the submit shortcut (Ctrl+S).
      def submit_shortcut?(event)
        Charming.key_of(event) == :s && event.respond_to?(:ctrl) && event.ctrl
      end

      # On Enter: submit when the last focusable field is active, otherwise advance focus.
      def advance_or_submit
        return submit if last_focusable?

        move_focus(+1)
      end

      # Validates all fields, focuses the first invalid one, and returns
      # Result.submitted(values) when there are no errors.
      def submit
        state[:errors] = validation_errors
        focus_first_error unless state[:errors].empty?
        return Result.handled unless state[:errors].empty?

        Result.submitted(values.dup)
      end

      # Runs each field's validator and collects per-field error messages.
      def validation_errors
        fields.each_with_object({}) do |field, errors|
          messages = field.validate
          errors[field.name] = messages unless messages.empty?
        end
      end

      # Moves focus to the first focusable field with errors, when any.
      def focus_first_error
        invalid = fields.index { |field| field.focusable? && state[:errors].key?(field.name) }
        state[:focus_index] = invalid if invalid
      end

      # Returns the field at the current focus index, or nil when out of range.
      def current_field
        fields[state[:focus_index]]
      end

      # Moves focus by *direction* (forward or backward) through the focusable fields.
      def move_focus(direction)
        indices = focusable_indices
        return nil if indices.empty?

        current = indices.index(state[:focus_index]) || 0
        state[:focus_index] = indices[(current + direction) % indices.length]
        Result.handled
      end

      # True when the current focus index is the last focusable field.
      def last_focusable?
        focusable_indices.last == state[:focus_index]
      end

      # Indices of focusable fields, memoized.
      def focusable_indices
        @focusable_indices ||= fields.each_index.select { |index| fields[index].focusable? }
      end

      # The first index of a focusable field, or nil when no fields are focusable.
      def first_focusable_index
        fields.each_index.find { |index| fields[index].focusable? }
      end

      # On initialization, ensures :focus_index points at a focusable field.
      def clamp_focus
        return if focusable_indices.empty?
        return if focusable_indices.include?(state[:focus_index])

        state[:focus_index] = focusable_indices.first
      end
    end
  end
end
