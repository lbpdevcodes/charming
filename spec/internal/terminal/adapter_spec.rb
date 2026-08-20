# frozen_string_literal: true

require "stringio"

RSpec.describe Charming::Internal::Terminal::Adapter do
  shared_examples "a terminal adapter" do
    it "includes the adapter contract" do
      expect(adapter).to be_a(described_class)
    end

    it "reads events with an optional timeout" do
      expect(adapter.read_event(timeout: 0.1)).to eq(event)
    end

    it "returns terminal dimensions" do
      expect(adapter.size).to eq([width, height])
    end

    it "supports full-frame rendering primitives" do
      expect { adapter.clear }.not_to raise_error
      expect { adapter.move_cursor(1, 1) }.not_to raise_error
      expect { adapter.write_frame("frame") }.not_to raise_error
    end

    it "supports partial line rendering with the current frame" do
      expect { adapter.write_lines([[1, "updated"]], frame: "updated") }.not_to raise_error
    end

    it "supports terminal lifecycle primitives" do
      expect { adapter.enter_alt_screen }.not_to raise_error
      expect { adapter.hide_cursor }.not_to raise_error
      expect { adapter.show_cursor }.not_to raise_error
      expect { adapter.leave_alt_screen }.not_to raise_error
    end
  end

  let(:event) { Charming::Events::KeyEvent.new(key: :q) }

  context "with MemoryBackend" do
    let(:width) { 100 }
    let(:height) { 40 }
    let(:adapter) do
      Charming::Internal::Terminal::MemoryBackend.new(
        events: [event],
        width: width,
        height: height
      )
    end

    it_behaves_like "a terminal adapter"
  end

  context "with TTYBackend" do
    before do
      stub_const(
        "AdapterSpecReader",
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
        "AdapterSpecCursor",
        Class.new do
          def self.show = "show"
          def self.hide = "hide"
          def self.clear_screen = "clear"
          def self.move_to(column, row) = "move:#{column}:#{row}"
        end
      )

      stub_const(
        "AdapterSpecScreen",
        Class.new(StringIO) do
          def winsize = [50, 120] # IO#winsize reports [rows, columns]
        end
      )
    end

    let(:width) { 120 }
    let(:height) { 50 }
    let(:event) { Charming::Events::KeyEvent.new(key: :q, char: "q") }
    let(:adapter) do
      Charming::Internal::Terminal::TTYBackend.new(
        input: StringIO.new,
        output: AdapterSpecScreen.new,
        reader: AdapterSpecReader.new(keys: {"q" => "q"}, keypresses: ["q"]),
        cursor: AdapterSpecCursor
      )
    end

    it_behaves_like "a terminal adapter"
  end

  it "raises a clear error for unimplemented contract methods" do
    adapter = Class.new { include Charming::Internal::Terminal::Adapter }.new

    expect { adapter.size }.to raise_error(NotImplementedError, /must implement #size/)
  end
end
