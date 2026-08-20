# frozen_string_literal: true

RSpec.describe Charming::Components::TextInput do
  def key(name, char: nil)
    Charming::Events::KeyEvent.new(key: name, char: char)
  end

  it "renders the cursor before the placeholder when empty" do
    input = described_class.new(placeholder: "Search")

    expect(input.render).to eq("|Search")
  end

  it "inserts printable characters at the cursor" do
    input = described_class.new(value: "ac", cursor: 1)

    handled = input.handle_key(key(:b, char: "b"))

    expect(handled).to eq(Charming::Components::Result.handled)
    expect(input.value).to eq("abc")
    expect(input.cursor).to eq(2)
    expect(input.render).to eq("ab|c")
  end

  it "moves the cursor left and right" do
    input = described_class.new(value: "abc")

    input.handle_key(key(:left))
    input.handle_key(key(:left))
    input.handle_key(key(:right))

    expect(input.cursor).to eq(2)
    expect(input.render).to eq("ab|c")
  end

  it "moves the cursor home and end" do
    input = described_class.new(value: "abc")

    input.handle_key(key(:home))
    expect(input.render).to eq("|abc")

    input.handle_key(key(:end))
    expect(input.render).to eq("abc|")
  end

  it "deletes before the cursor with backspace" do
    input = described_class.new(value: "abc", cursor: 2)

    input.handle_key(key(:backspace))

    expect(input.value).to eq("ac")
    expect(input.render).to eq("a|c")
  end

  it "deletes at the cursor with delete" do
    input = described_class.new(value: "abc", cursor: 1)

    input.handle_key(key(:delete))

    expect(input.value).to eq("ac")
    expect(input.render).to eq("a|c")
  end

  it "submits the current value on Enter" do
    input = described_class.new(value: "buy milk")

    result = input.handle_key(key(:enter))

    expect(result).to eq(Charming::Components::Result.submitted("buy milk"))
    expect(input.value).to eq("buy milk")
  end

  it "submits an empty value on Enter" do
    input = described_class.new

    expect(input.handle_key(key(:enter))).to eq(Charming::Components::Result.submitted(""))
  end

  it "ignores unsupported keys" do
    input = described_class.new(value: "abc")

    handled = input.handle_key(key(:up))

    expect(handled).to be_nil
    expect(input.value).to eq("abc")
  end

  it "renders with a fixed width" do
    input = described_class.new(value: "abc", width: 6)

    expect(input.render).to eq("abc|  ")
  end
end
