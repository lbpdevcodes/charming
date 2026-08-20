# frozen_string_literal: true

RSpec.describe Charming::Components::StatusBar do
  let(:theme) { Charming::UI::Theme.default }

  def plain(bar)
    Charming::UI::Width.strip_ansi(bar.render)
  end

  it "renders left, center, and right segments at their positions" do
    bar = described_class.new(width: 30, left: "MODE", center: "mid", right: "9:41", theme: theme)
    output = plain(bar)
    expect(output.length).to eq(30)
    expect(output).to start_with("MODE")
    expect(output).to end_with("9:41")
    expect(output).to include("mid")
    # center segment is actually centered
    expect(output.index("mid")).to be_within(2).of((30 - 3) / 2)
  end

  it "renders key hints in the center when no explicit center" do
    bar = described_class.new(width: 40, hints: [["q", "quit"], ["?", "help"]], theme: theme)
    expect(plain(bar)).to include("q quit  ? help")
  end

  it "pads to the full width when segments are empty" do
    bar = described_class.new(width: 12, theme: theme)
    expect(plain(bar).length).to eq(12)
  end

  it "clips segments that exceed the width" do
    bar = described_class.new(width: 10, left: "averyverylonglabel", theme: theme)
    expect(plain(bar).length).to eq(10)
  end
end
