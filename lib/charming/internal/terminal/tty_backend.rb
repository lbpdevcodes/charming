# frozen_string_literal: true

require "io/console"
require "tty-reader"

module Charming
  module Internal
    module Terminal
      # TTYBackend is the production terminal backend. It reads key and mouse events from
      # a TTY::Reader, normalizes them via KeyNormalizer and MouseParser, and writes output
      # frames using Terminal::Cursor sequences and IO#winsize for dimensions. It also
      # installs SIGWINCH and SIGINFO handlers so the runtime can react to terminal resize
      # and focus changes.
      class TTYBackend
        include Adapter

        # Escape sequences for entering/leaving the alternate screen buffer.
        ALT_SCREEN_ON = "\e[?1049h"
        ALT_SCREEN_OFF = "\e[?1049l"

        # Escape sequences for disabling/enabling automatic line wrapping during frame writes.
        AUTO_WRAP_OFF = "\e[?7l"
        AUTO_WRAP_ON = "\e[?7h"

        # Escape sequences for enabling/disabling bracketed-paste mode, and the markers
        # the terminal wraps around pasted text.
        BRACKETED_PASTE_ON = "\e[?2004h"
        BRACKETED_PASTE_OFF = "\e[?2004l"
        PASTE_START = "\e[200~"
        PASTE_END = "\e[201~"

        # Escape sequences for terminal focus reporting and the focus-in/out markers.
        FOCUS_REPORTING_ON = "\e[?1004h"
        FOCUS_REPORTING_OFF = "\e[?1004l"
        FOCUS_IN = "\e[I"
        FOCUS_OUT = "\e[O"

        # *input* and *output* default to `$stdin`/`$stdout` for normal terminal use;
        # tests can inject IO objects. *reader* is a TTY::Reader instance (created from
        # *input*/*output* when nil). *cursor* is the Terminal::Cursor module used for
        # cursor control sequences.
        def initialize(input: $stdin, output: $stdout, reader: nil, cursor: Cursor)
          @input = input
          @output = output
          @reader = reader || TTY::Reader.new(input: input, output: output)
          @cursor = cursor
          @key_normalizer = KeyNormalizer.new(@reader)
          @resized = false
          @previous_winch_handler = nil
          @mouse_enabled = false
        end

        # Reads the next event. If a SIGWINCH was received, returns a ResizeEvent with the
        # current terminal dimensions. Bracketed pastes return a PasteEvent; mouse escape
        # sequences are parsed by MouseParser; other input is normalized via KeyNormalizer.
        # Returns nil on timeout.
        def read_event(timeout: nil)
          return resize_event if resized?

          raw = @reader.read_keypress(echo: false, raw: true, nonblock: timeout)
          return nil unless raw
          return Events::FocusEvent.new(focused: true) if raw == FOCUS_IN
          return Events::FocusEvent.new(focused: false) if raw == FOCUS_OUT
          return paste_event(raw) if raw.start_with?(PASTE_START)
          return MouseParser.parse(raw) if MouseParser.sequence?(raw)

          @key_normalizer.normalize(raw)
        rescue Errno::EAGAIN, IO::WaitReadable
          nil
        end

        # True when stdin has bytes ready to read right now — a genuine nonblocking check (0s
        # wait), unlike read_event whose tty-reader nonblock path waits up to 0.1s. Lets the
        # runtime drain buffered key auto-repeat and stop the instant the buffer empties.
        def input_pending?
          resized? || !@input.wait_readable(0).nil?
        end

        # Emits the ANSI sequence enabling terminal focus reporting. Idempotent.
        def enable_focus_reporting
          return if @focus_reporting

          write_control(FOCUS_REPORTING_ON)
          @focus_reporting = true
        end

        # Emits the ANSI sequence disabling terminal focus reporting. Idempotent.
        def disable_focus_reporting
          return unless @focus_reporting

          write_control(FOCUS_REPORTING_OFF)
          @focus_reporting = false
        end

        # Emits the ANSI sequence enabling bracketed-paste mode. Idempotent.
        def enable_bracketed_paste
          return if @bracketed_paste

          write_control(BRACKETED_PASTE_ON)
          @bracketed_paste = true
        end

        # Emits the ANSI sequence disabling bracketed-paste mode. Idempotent.
        def disable_bracketed_paste
          return unless @bracketed_paste

          write_control(BRACKETED_PASTE_OFF)
          @bracketed_paste = false
        end

        # Returns the terminal to its normal state for a shell suspend (Ctrl+Z):
        # reporting modes off, cursor visible, primary screen, cooked input.
        def suspend
          @mouse_was_enabled = @mouse_enabled
          disable_mouse_tracking
          disable_bracketed_paste
          disable_focus_reporting
          show_cursor
          leave_alt_screen
          @input.cooked! if @input.respond_to?(:cooked!)
        end

        # Re-enters the TUI after a resume (SIGCONT): raw/no-echo input, alt
        # screen, hidden cursor, and the reporting modes that were active before
        # the suspend. The caller is responsible for triggering a repaint.
        def resume
          @input.raw! if @input.respond_to?(:raw!)
          @input.echo = false if @input.respond_to?(:echo=)
          enter_alt_screen
          hide_cursor
          enable_mouse_tracking(motion: @mouse_motion || :drag) if @mouse_was_enabled
          enable_bracketed_paste
          enable_focus_reporting
          clear
        end

        # The OSC 11 background-color query and the terminators a reply may end with.
        BACKGROUND_QUERY = "\e]11;?\e\\"
        OSC_TERMINATORS = ["\a", "\e\\"].freeze

        # Queries the terminal's background color via OSC 11 and classifies the
        # reply as :dark or :light. Returns nil when the input cannot be polled,
        # the terminal stays silent past *timeout*, or the reply is unparseable.
        # Call before the event loop starts — a reply arriving later would be
        # read as keyboard input.
        def query_background_color(timeout: 0.15)
          return nil unless @input.respond_to?(:wait_readable)

          write_control(BACKGROUND_QUERY)
          UI::Background.parse_osc11(read_reply(timeout))
        end

        # Keeps terminal input in raw/no-echo mode for the duration of a TUI run. Reading a
        # single keypress in raw mode is not enough: keys pressed while rendering or dispatching
        # events can otherwise be echoed into the alternate screen before the next read.
        def with_raw_input
          return yield unless @input.respond_to?(:tty?) && @input.tty?
          return yield unless @input.respond_to?(:raw) && @input.respond_to?(:noecho)

          @input.raw do
            @input.noecho do
              yield
            end
          end
        end

        # Installs a SIGWINCH handler that sets the internal `@resized` flag, returning
        # the previous handler so it can be restored on teardown.
        def install_resize_handler
          @previous_winch_handler = Signal.trap("WINCH") { @resized = true }
        end

        # Installs a SIGINFO handler that marks the terminal as having received focus.
        # SIGINFO is sent by some terminals (notably macOS Terminal.app) on focus changes.
        def install_focus_handler
          # Terminal focus change: some terminals send a special sequence
          # when focus changes. We use this to throttle rendering.
          @previous_focus_handler = Signal.trap("INFO") { @focused = true }
        end

        # Restores the previous SIGINFO handler.
        def restore_focus_handler
          Signal.trap("INFO", @previous_focus_handler) if @previous_focus_handler
          @previous_focus_handler = nil
        end

        # Restores the previous SIGWINCH handler captured by `install_resize_handler`.
        def restore_resize_handler
          Signal.trap("WINCH", @previous_winch_handler) if @previous_winch_handler
          @previous_winch_handler = nil
        end

        # Emits the ANSI sequences that enable terminal mouse reporting (press, motion, SGR).
        # Idempotent: skipped when mouse tracking is already enabled.
        def enable_mouse_tracking(motion: :drag)
          return if @mouse_enabled

          write_control("\e[?1000h")
          write_control("\e[?1002h")
          write_control("\e[?1003h") if motion == :all
          write_control("\e[?1006h")
          @mouse_enabled = true
          @mouse_motion = motion
        end

        # Emits the ANSI sequences that disable terminal mouse reporting. Idempotent.
        def disable_mouse_tracking
          return unless @mouse_enabled

          write_control("\e[?1000l")
          write_control("\e[?1002l")
          write_control("\e[?1003l") if @mouse_motion == :all
          write_control("\e[?1006l")
          @mouse_enabled = false
        end

        # Returns whether mouse tracking is currently enabled on this backend.
        def mouse_enabled?
          @mouse_enabled
        end

        # Manually flags the backend as resized (used by tests or external integrations).
        def notify_resize
          @resized = true
        end

        # Writes a full multi-line *frame* to the terminal, disabling auto-wrap during
        # the write so overlong lines don't disturb the screen layout.
        def write_frame(frame)
          without_auto_wrap do
            write_positioned_lines(frame.to_s.lines(chomp: true))
          end
        end

        # Writes a partial frame composed of [row, line] tuples (1-based rows).
        def write_lines(line_changes, **)
          without_auto_wrap do
            write_control(line_changes.map { |row, line| positioned_line(row, line) }.join)
          end
        end

        # Writes an out-of-band escape *sequence* (image transmission, clipboard, notification, title)
        # raw — no cursor positioning, line-clearing, or auto-wrap handling that would corrupt it.
        def write_escape(sequence)
          write_control(sequence.payload)
        end

        # Enters the alternate screen buffer.
        def enter_alt_screen
          write_control(ALT_SCREEN_ON)
        end

        # Leaves the alternate screen buffer.
        def leave_alt_screen
          write_control(ALT_SCREEN_OFF)
        end

        # Shows the terminal cursor.
        def show_cursor
          write_control(@cursor.show)
        end

        # Hides the terminal cursor.
        def hide_cursor
          write_control(@cursor.hide)
        end

        # Clears the terminal screen and moves the cursor to (1, 1).
        def clear
          write_control(@cursor.clear_screen)
        end

        # Moves the terminal cursor to the given 1-based (row, column).
        def move_cursor(row, column)
          write_control(@cursor.move_to(column - 1, row - 1))
        end

        # Returns the current terminal dimensions as [width, height]: IO#winsize on the
        # output/input streams, then COLUMNS/LINES, then 80x24.
        def size = Size.measure(@output, @input)

        private

        # Accumulates an OSC reply from the input until a terminator arrives or
        # *timeout* elapses. Returns whatever was read (possibly "").
        def read_reply(timeout)
          reply = +""
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
          while (remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) > 0
            break unless @input.wait_readable(remaining)
            break if append_reply_chunk(reply).nil?
            break if OSC_TERMINATORS.any? { |terminator| reply.include?(terminator) }
          end
          reply
        end

        # Reads one available chunk into *reply*; nil at EOF or read error.
        def append_reply_chunk(reply)
          reply << @input.readpartial(64)
        rescue IOError, SystemCallError
          nil
        end

        # True when the SIGWINCH flag has been set since the last read_event.
        def resized?
          @resized
        end

        # Consumes the resize flag, measures the current terminal, and returns a ResizeEvent.
        def resize_event
          @resized = false
          width, height = size
          Events::ResizeEvent.new(width: width, height: height)
        end

        # Builds a PasteEvent from a bracketed-paste chunk, reading further keypresses
        # until the paste-end marker arrives (large pastes can span multiple reads).
        def paste_event(raw)
          buffer = raw.delete_prefix(PASTE_START)
          until buffer.include?(PASTE_END)
            chunk = @reader.read_keypress(echo: false, raw: true, nonblock: 0.2)
            break unless chunk

            buffer << chunk
          end
          Events::PasteEvent.new(text: buffer.sub(/#{Regexp.escape(PASTE_END)}.*\z/mo, ""))
        end

        # Writes a raw escape *sequence* to the output stream and flushes.
        def write_control(sequence)
          @output.write(sequence)
          @output.flush
        end

        # Writes *lines* one row at a time, with each line preceded by an ANSI cursor
        # position and a clear-to-end-of-line sequence.
        def write_positioned_lines(lines)
          write_control(lines.each_with_index.map { |line, index| positioned_line(index + 1, line) }.join)
        end

        # Resets SGR before and after each row so partial repaint rows cannot inherit
        # colors/backgrounds from the previous physical terminal line.
        def positioned_line(row, line)
          "\e[0m\e[#{row};1H\e[2K#{line}\e[0m"
        end

        # Disables auto-wrap, yields, then re-enables it and flushes the output.
        def without_auto_wrap
          @output.write(AUTO_WRAP_OFF)
          yield
        ensure
          @output.write(AUTO_WRAP_ON)
          @output.flush
        end
      end
    end
  end
end
