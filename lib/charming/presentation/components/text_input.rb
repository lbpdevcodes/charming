# frozen_string_literal: true

module Charming
  module Components
    # TextInput is a single-line text editor component. Supports printable character insertion,
    # cursor movement (left/right/home/end), and deletion (backspace/delete). The component
    # exposes its `value` and `cursor` positions as reader methods; when an explicit `width:`
    # is given, the rendered output is padded to that width via a UI::Style.
    #
    # Options:
    # - `masked: true` renders every character as `*` (password entry)
    # - `history: [...]` enables REPL-style recall — up/down cycle through prior values
    class TextInput < Component
      include KeyboardHandler

      # Maps editing keys (left/right/home/end/backspace/delete) to the instance
      # methods they dispatch via KeyboardHandler. Each symbol key (e.g., :left)
      # maps to a method (e.g., :move_left) that adjusts cursor position or text content.
      KEY_ACTIONS = {
        left: :move_left,
        right: :move_right,
        home: :move_home,
        end: :move_end,
        backspace: :delete_before_cursor,
        delete: :delete_at_cursor
      }.freeze

      # The current input string and the character offset of the cursor within it.
      attr_reader :value, :cursor

      # *value* is the initial text. *placeholder* is shown when the value is empty.
      # *width* optionally constrains the rendered output width; *cursor* defaults to the end.
      # *masked* renders characters as `*`. *history* is an array of prior values cycled
      # with up/down (most recent last, like a shell).
      def initialize(value: "", placeholder: "", width: nil, cursor: nil, masked: false, history: nil)
        super()
        @value = value.dup
        @placeholder = placeholder
        @width = width
        @cursor = cursor || @value.length
        @masked = masked
        @history = history
        @history_index = nil
        @draft = nil
        clamp_position
      end

      # Free-typed characters belong to this component while it is focused.
      def captures_text?
        true
      end

      # Handles key events. Inserts printable characters, submits on Enter
      # (returning `Result.submitted(value)` so a focused slot dispatches
      # `<slot>_submitted(value)`), recalls history on up/down (when enabled),
      # otherwise dispatches via KEY_ACTIONS.
      # Returns Result.handled or Result.submitted(value) when the event was consumed, nil otherwise.
      def handle_key(event)
        return Result.handled if character_event?(event) && insert(event.char)

        key = Charming.key_of(event)
        return Result.submitted(value) if key == :enter
        return Result.handled if history_event(key)

        super
      end

      # Inserts pasted text at the cursor (newlines and control characters are
      # stripped — this is a single-line input). Returns Result.handled.
      def handle_paste(event)
        sanitized = event.text.to_s.gsub(/[[:cntrl:]]/, "")
        insert(sanitized) unless sanitized.empty?
        Result.handled
      end

      # Renders the value with a cursor marker. When *width* was given at construction, the
      # output is padded to that width via the configured style.
      def render
        rendered = render_value
        @width ? style.width(@width).render(rendered) : rendered
      end

      private

      attr_reader :placeholder

      # True when *event* carries a single printable character that should be inserted.
      def character_event?(event)
        event.respond_to?(:char) && event.char && event.char.length == 1 && printable?(event.char)
      end

      # True when *char* is not a control character (and therefore safe to insert).
      def printable?(char)
        !char.match?(/[[:cntrl:]]/)
      end

      # Inserts *char* at the cursor and advances the cursor by its character length.
      def insert(char)
        @value = value[0...cursor] + char + value[cursor..]
        @cursor += char.length
      end

      # Moves the cursor one position left, when possible.
      def move_left
        @cursor -= 1 if cursor.positive?
      end

      # Moves the cursor one position right, when possible.
      def move_right
        @cursor += 1 if cursor < value.length
      end

      # Moves the cursor to the start of the value.
      def move_home
        @cursor = 0
      end

      # Moves the cursor to the end of the value.
      def move_end
        @cursor = value.length
      end

      # Deletes the character before the cursor (backspace behavior).
      def delete_before_cursor
        return if cursor.zero?

        @value = value[0...(cursor - 1)] + value[cursor..]
        @cursor -= 1
      end

      # Deletes the character at the cursor (delete-key behavior).
      def delete_at_cursor
        return if cursor >= value.length

        @value = value[0...cursor] + value[(cursor + 1)..]
      end

      # Cycles through history on :up / :down. Returns true when the event was consumed.
      def history_event(key)
        return false unless @history && !@history.empty?

        case key
        when :up then recall_previous
        when :down then recall_next
        else false
        end
      end

      # Steps back through history (saving the in-progress draft first).
      def recall_previous
        if @history_index.nil?
          @draft = value
          @history_index = @history.length - 1
        elsif @history_index.positive?
          @history_index -= 1
        end
        replace_value(@history[@history_index])
        true
      end

      # Steps forward through history; past the newest entry restores the draft.
      def recall_next
        return false if @history_index.nil?

        @history_index += 1
        if @history_index >= @history.length
          @history_index = nil
          replace_value(@draft.to_s)
        else
          replace_value(@history[@history_index])
        end
        true
      end

      # Replaces the value and moves the cursor to the end.
      def replace_value(new_value)
        @value = new_value.dup
        @cursor = @value.length
      end

      # Renders the value with a "|" cursor marker at the current position. When the value is
      # empty, the placeholder is rendered instead, preceded by the cursor marker. Masked
      # inputs render `*` per character.
      def render_value
        return cursor_marker + placeholder if value.empty?

        shown = display_value
        shown[0...cursor] + cursor_marker + shown[cursor..]
      end

      # The value as displayed: masked inputs substitute `*` for every character.
      def display_value
        @masked ? "*" * value.length : value
      end

      # The literal character used to mark the cursor position in `render`.
      def cursor_marker
        "|"
      end

      # Clamps the cursor to the valid range `[0, value.length]`.
      def clamp_position
        @cursor = cursor.clamp(0, value.length)
      end
    end
  end
end
