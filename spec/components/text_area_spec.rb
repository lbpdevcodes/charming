# frozen_string_literal: true

RSpec.describe Charming::Components::TextArea do
  def key(name, char: nil, shift: false, ctrl: false)
    Charming::Events::KeyEvent.new(key: name, char: char, shift: shift, ctrl: ctrl)
  end

  it "renders the cursor before the placeholder when empty" do
    area = described_class.new(placeholder: "Bio")

    expect(area.render).to eq("|Bio")
  end

  it "inserts printable characters at the cursor" do
    area = described_class.new(value: "ac", cursor: 1)

    expect(area.handle_key(key(:b, char: "b"))).to eq(Charming::Components::Result.handled)

    expect(area.value).to eq("abc")
    expect(area.cursor).to eq(2)
    expect(area.render).to eq("ab|c")
  end

  it "inserts a newline on plain enter by default" do
    area = described_class.new(value: "abc")

    expect(area.handle_key(key(:enter, char: "\n"))).to eq(Charming::Components::Result.handled)
    expect(area.value).to eq("abc\n")
  end

  it "creates blank lines from consecutive enters" do
    area = described_class.new(value: "para one")

    2.times { area.handle_key(key(:enter, char: "\n")) }
    area.handle_key(key(:p, char: "p"))

    expect(area.value).to eq("para one\n\np")
  end

  it "leaves plain enter unhandled when enter_newline is disabled" do
    area = described_class.new(value: "abc", enter_newline: false)

    expect(area.handle_key(key(:enter, char: "\n"))).to be_nil
    expect(area.value).to eq("abc")
  end

  it "inserts newlines with shift-enter, ctrl-j, or ctrl-n regardless of enter_newline" do
    area = described_class.new(enter_newline: false)

    expect(area.handle_key(key(:enter, char: "\n", shift: true))).to eq(Charming::Components::Result.handled)
    expect(area.handle_key(key(:j, ctrl: true))).to eq(Charming::Components::Result.handled)
    expect(area.handle_key(key(:n, ctrl: true))).to eq(Charming::Components::Result.handled)

    expect(area.value).to eq("\n\n\n")
    expect(area.render).to eq("\n\n\n|")
  end

  it "moves left and right across line boundaries" do
    area = described_class.new(value: "ab\ncd", cursor: 3)

    area.handle_key(key(:left))
    expect(area.render).to eq("ab|\ncd")

    area.handle_key(key(:right))
    expect(area.render).to eq("ab\n|cd")
  end

  it "moves home and end on the current line" do
    area = described_class.new(value: "ab\ncde", cursor: 5)

    area.handle_key(key(:home))
    expect(area.render).to eq("ab\n|cde")

    area.handle_key(key(:end))
    expect(area.render).to eq("ab\ncde|")
  end

  it "moves vertically while preserving preferred column" do
    area = described_class.new(value: "abcd\nef\nghij", cursor: 3)

    area.handle_key(key(:down))
    expect(area.cursor).to eq(7)

    area.handle_key(key(:down))
    expect(area.cursor).to eq(11)
    expect(area.render).to eq("abcd\nef\nghi|j")
  end

  it "deletes before the cursor across line boundaries" do
    area = described_class.new(value: "ab\ncd", cursor: 3)

    area.handle_key(key(:backspace))

    expect(area.value).to eq("abcd")
    expect(area.render).to eq("ab|cd")
  end

  it "deletes at the cursor across line boundaries" do
    area = described_class.new(value: "ab\ncd", cursor: 2)

    area.handle_key(key(:delete))

    expect(area.value).to eq("abcd")
    expect(area.render).to eq("ab|cd")
  end

  it "clips and pads content with fixed width and height" do
    area = described_class.new(value: "abcdef", width: 4, height: 2)

    expect(area.render).to eq("abcd\n    ")
  end

  it "scrolls vertically to keep the cursor visible" do
    area = described_class.new(value: "one\ntwo\nthree", height: 2)

    expect(area.offset).to eq(1)
    expect(area.render).to eq("two\nthree|")
  end

  it "scrolls by pages" do
    area = described_class.new(value: "one\ntwo\nthree", height: 1, cursor: 0)

    area.handle_key(key(:page_down))
    expect(area.offset).to eq(1)

    area.handle_key(key(:page_up))
    expect(area.offset).to eq(0)
  end
end
