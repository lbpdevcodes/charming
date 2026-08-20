# frozen_string_literal: true

RSpec.describe Charming::Components::Badge do
  let(:theme) { Charming::UI::Theme.default }

  it "renders the label padded inside the themed style" do
    badge = described_class.new("v1.2", theme: theme)
    expect(Charming::UI::Width.strip_ansi(badge.render)).to eq(" v1.2 ")
  end

  it "accepts a custom style" do
    style = Charming::UI.style.foreground(:red)
    badge = described_class.new("err", style: style)
    expect(badge.render).to eq(style.render(" err "))
  end
end
