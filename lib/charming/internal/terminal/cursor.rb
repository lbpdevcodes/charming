# frozen_string_literal: true

module Charming
  module Internal
    module Terminal
      # Cursor emits the ANSI escape sequences for cursor visibility, screen clearing,
      # and positioning. Replaces tty-cursor (a stateless escape-string generator) with
      # the four sequences TTYBackend actually uses, asserted byte-for-byte in
      # spec/internal/terminal/cursor_spec.rb.
      module Cursor
        module_function

        # Shows the terminal cursor (DECTCEM set).
        def show = "\e[?25h"

        # Hides the terminal cursor (DECTCEM reset).
        def hide = "\e[?25l"

        # Clears the whole screen (ED 2).
        def clear_screen = "\e[2J"

        # Moves the cursor to zero-based *column*/*row* (CUP is one-based row;column).
        def move_to(column, row)
          "\e[#{row + 1};#{column + 1}H"
        end
      end
    end
  end
end
