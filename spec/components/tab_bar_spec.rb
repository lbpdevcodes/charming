# frozen_string_literal: true

RSpec.describe Charming::Components::TabBar do
  let(:tabs) { ["Files", "Search", "Git"] }
  let(:theme) { Charming::UI::Theme.default }

  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  it "renders all tabs" do
    bar = described_class.new(tabs: tabs, theme: theme)
    plain = Charming::UI::Width.strip_ansi(bar.render)
    expect(plain).to include("Files")
    expect(plain).to include("Search")
    expect(plain).to include("Git")
  end

  it "moves right and left" do
    bar = described_class.new(tabs: tabs)
    bar.handle_key(key(:right))
    expect(bar.selected_index).to eq(1)
    bar.handle_key(key(:left))
    expect(bar.selected_index).to eq(0)
  end

  it "supports vim h/l keys" do
    bar = described_class.new(tabs: tabs)
    bar.handle_key(key(:l))
    expect(bar.selected_index).to eq(1)
    bar.handle_key(key(:h))
    expect(bar.selected_index).to eq(0)
  end

  it "clamps at the ends" do
    bar = described_class.new(tabs: tabs, selected_index: 2)
    bar.handle_key(key(:right))
    expect(bar.selected_index).to eq(2)
  end

  it "returns Result.selected(index) on enter" do
    bar = described_class.new(tabs: tabs, selected_index: 1)
    expect(bar.handle_key(key(:enter))).to eq(Charming::Components::Result.selected(1))
  end

  it "selects a tab on click" do
    bar = described_class.new(tabs: tabs)
    # " Files " is 7 wide + 2 separator → "Search" tab starts at column 9
    event = Charming::Events::MouseEvent.new(button: 0, x: 10, y: 0)
    expect(bar.handle_mouse(event)).to eq(Charming::Components::Result.handled)
    expect(bar.selected_index).to eq(1)
  end

  it "ignores clicks between tabs" do
    bar = described_class.new(tabs: tabs)
    event = Charming::Events::MouseEvent.new(button: 0, x: 8, y: 0)
    expect(bar.handle_mouse(event)).to be_nil
  end

  it "handles empty tabs gracefully" do
    bar = described_class.new(tabs: [])
    expect(bar.handle_key(key(:enter))).to be_nil
    expect(bar.render).to eq("")
  end

  describe "#tabs=" do
    it "replaces the tabs and clamps the selection" do
      bar = described_class.new(tabs: %w[one two three], selected_index: 2)

      bar.tabs = %w[only]

      expect(bar.tabs).to eq(%w[only])
      expect(bar.selected_index).to eq(0)
    end
  end
end
