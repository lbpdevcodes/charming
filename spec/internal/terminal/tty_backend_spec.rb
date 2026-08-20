# frozen_string_literal: true

require "stringio"

RSpec.describe Charming::Internal::Terminal::TTYBackend do
  before do
    stub_const(
      "TTYBackendSpecReader",
      Class.new do
        attr_reader :console

        def initialize(keys:, keypresses: [])
          @console = Struct.new(:keys).new(keys)
          @keypresses = keypresses
        end

        def read_keypress(*)
          @keypresses.shift
        end
      end
    )

    stub_const(
      "TTYBackendSpecCursor",
      Class.new do
        def self.show
          "show"
        end

        def self.hide
          "hide"
        end

        def self.clear_screen
          "clear"
        end

        def self.move_to(column, row)
          "move:#{column}:#{row}"
        end
      end
    )

    stub_const(
      "TTYBackendSpecScreen",
      Class.new(StringIO) do
        def winsize = [40, 120] # IO#winsize reports [rows, columns]
      end
    )
  end

  it "normalizes named keys from tty-reader" do
    reader = TTYBackendSpecReader.new(keys: {"\e[A" => :up}, keypresses: ["\e[A"])
    backend = described_class.new(input: StringIO.new, output: StringIO.new, reader: reader)

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::KeyEvent.new(key: :up))
  end

  it "normalizes return as enter" do
    reader = TTYBackendSpecReader.new(keys: {"\r" => :return}, keypresses: ["\r"])
    backend = described_class.new(input: StringIO.new, output: StringIO.new, reader: reader)

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::KeyEvent.new(key: :enter, char: "\n"))
  end

  it "normalizes printable characters" do
    reader = TTYBackendSpecReader.new(keys: {}, keypresses: ["q"])
    backend = described_class.new(input: StringIO.new, output: StringIO.new, reader: reader)

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::KeyEvent.new(key: :q, char: "q"))
  end

  it "preserves printable chars when tty-reader maps them as named keys" do
    reader = TTYBackendSpecReader.new(keys: {"q" => "q"}, keypresses: ["q"])
    backend = described_class.new(input: StringIO.new, output: StringIO.new, reader: reader)

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::KeyEvent.new(key: :q, char: "q"))
  end

  it "normalizes control-modified keys" do
    reader = TTYBackendSpecReader.new(keys: {"\u0003" => :ctrl_c}, keypresses: ["\u0003"])
    backend = described_class.new(input: StringIO.new, output: StringIO.new, reader: reader)

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::KeyEvent.new(key: :c, ctrl: true))
  end

  it "writes terminal control sequences" do
    output = StringIO.new
    backend = described_class.new(
      input: StringIO.new,
      output: output,
      reader: TTYBackendSpecReader.new(keys: {}),
      cursor: TTYBackendSpecCursor
    )

    backend.hide_cursor
    backend.clear
    backend.move_cursor(1, 1)
    backend.show_cursor

    expect(output.string).to eq("hideclearmove:0:0show")
  end

  it "writes batched line updates" do
    output = StringIO.new
    backend = described_class.new(
      input: StringIO.new,
      output: output,
      reader: TTYBackendSpecReader.new(keys: {}),
      cursor: TTYBackendSpecCursor
    )

    backend.write_lines([[2, "updated"], [4, ""]])

    expect(output.string).to eq("\e[?7l\e[0m\e[2;1H\e[2Kupdated\e[0m\e[0m\e[4;1H\e[2K\e[0m\e[?7h")
  end

  it "resets styling around every line update" do
    output = StringIO.new
    backend = described_class.new(
      input: StringIO.new,
      output: output,
      reader: TTYBackendSpecReader.new(keys: {}),
      cursor: TTYBackendSpecCursor
    )

    backend.write_lines([[2, "\e[31mred"], [3, "plain"]])

    expect(output.string).to eq("\e[?7l\e[0m\e[2;1H\e[2K\e[31mred\e[0m\e[0m\e[3;1H\e[2Kplain\e[0m\e[?7h")
  end

  it "writes full frames with positioned rows and auto-wrap disabled" do
    output = StringIO.new
    backend = described_class.new(
      input: StringIO.new,
      output: output,
      reader: TTYBackendSpecReader.new(keys: {}),
      cursor: TTYBackendSpecCursor
    )

    backend.write_frame("one\ntwo")

    expect(output.string).to eq("\e[?7l\e[0m\e[1;1H\e[2Kone\e[0m\e[0m\e[2;1H\e[2Ktwo\e[0m\e[?7h")
  end

  it "returns a resize event after a resize notification" do
    backend = described_class.new(
      input: StringIO.new,
      output: TTYBackendSpecScreen.new,
      reader: TTYBackendSpecReader.new(keys: {})
    )

    backend.notify_resize

    expect(backend.read_event(timeout: 0.1)).to eq(Charming::Events::ResizeEvent.new(width: 120, height: 40))
  end

  it "parses SGR mouse click (left button)" do
    reader = TTYBackendSpecReader.new(keys: {}, keypresses: ["\e[<0;10;5M"])
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output, reader: reader)

    event = backend.read_event(timeout: 0.1)

    expect(event).to be_a(Charming::Events::MouseEvent)
    expect(event.button).to eq(0)
    expect(event.x).to eq(9)
    expect(event.y).to eq(4)
  end

  it "parses SGR mouse scroll up" do
    reader = TTYBackendSpecReader.new(keys: {}, keypresses: ["\e[<64;10;5M"])
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output, reader: reader)

    event = backend.read_event(timeout: 0.1)

    expect(event).to be_a(Charming::Events::MouseEvent)
    expect(event.button).to eq(64)
    expect(event.x).to eq(9)
    expect(event.y).to eq(4)
  end

  it "parses SGR mouse release" do
    reader = TTYBackendSpecReader.new(keys: {}, keypresses: ["\e[<3;10;5M"])
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output, reader: reader)

    event = backend.read_event(timeout: 0.1)

    expect(event).to be_a(Charming::Events::MouseEvent)
    expect(event.button).to eq(3)
  end

  it "parses legacy mouse event" do
    # Legacy format: \e[M + 3 bytes (button, col, row) with 32 offset
    # button=0 (left), col=10, row=5 => bytes: 32, 42, 37
    raw = "\e[M#{[32, 42, 37].pack("CCC")}"
    reader = TTYBackendSpecReader.new(keys: {}, keypresses: [raw])
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output, reader: reader)

    event = backend.read_event(timeout: 0.1)

    expect(event).to be_a(Charming::Events::MouseEvent)
    expect(event.button).to eq(0)
    expect(event.x).to eq(10)
    expect(event.y).to eq(5)
  end

  it "enables mouse tracking" do
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output)

    backend.enable_mouse_tracking

    expect(backend.mouse_enabled?).to be true
    expect(output.string).to include("\e[?1000h")
    expect(output.string).to include("\e[?1006h")
  end

  it "disables mouse tracking" do
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output)

    backend.enable_mouse_tracking
    backend.disable_mouse_tracking

    expect(backend.mouse_enabled?).to be false
    expect(output.string).to include("\e[?1000l")
    expect(output.string).to include("\e[?1006l")
  end

  it "does not enable mouse tracking twice" do
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output)

    backend.enable_mouse_tracking
    backend.enable_mouse_tracking

    expect(output.string.scan("\e[?1000h").length).to eq(1)
  end

  it "does not enable all-motion tracking by default" do
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output)

    backend.enable_mouse_tracking
    backend.disable_mouse_tracking

    expect(output.string).not_to include("\e[?1003h")
    expect(output.string).not_to include("\e[?1003l")
  end

  it "enables and disables all-motion (hover) tracking when requested" do
    output = StringIO.new
    backend = described_class.new(input: StringIO.new, output: output)

    backend.enable_mouse_tracking(motion: :all)
    backend.disable_mouse_tracking

    expect(output.string).to include("\e[?1003h")
    expect(output.string).to include("\e[?1003l")
  end

  describe "#suspend and #resume" do
    it "returns the terminal to normal state on suspend and re-enters the TUI on resume" do
      output = StringIO.new
      backend = described_class.new(input: StringIO.new, output: output)
      backend.enter_alt_screen
      backend.hide_cursor
      backend.enable_mouse_tracking
      backend.enable_bracketed_paste
      backend.enable_focus_reporting

      backend.suspend
      suspended = output.string.dup
      backend.resume

      expect(suspended).to include("\e[?1049l", "\e[?1000l", "\e[?2004l", "\e[?1004l")
      resumed = output.string.delete_prefix(suspended)
      expect(resumed).to include("\e[?1049h", "\e[?1000h", "\e[?2004h", "\e[?1004h")
    end
  end

  describe "#query_background_color" do
    let(:replying_input) do
      Class.new(StringIO) do
        def wait_readable(_timeout = nil)
          !eof?
        end
      end
    end

    it "sends an OSC 11 query and classifies the terminal's reply" do
      input = replying_input.new("\e]11;rgb:1c1c/1c1c/2c2c\e\\")
      output = StringIO.new
      backend = described_class.new(input: input, output: output)

      expect(backend.query_background_color).to eq(:dark)
      expect(output.string).to include("\e]11;?\e\\")
    end

    it "returns nil when the terminal does not reply" do
      input = replying_input.new("")
      backend = described_class.new(input: input, output: StringIO.new)

      expect(backend.query_background_color(timeout: 0.01)).to be_nil
    end

    it "returns nil when the input cannot be polled" do
      backend = described_class.new(input: StringIO.new, output: StringIO.new)

      expect(backend.query_background_color).to be_nil
    end
  end
end
