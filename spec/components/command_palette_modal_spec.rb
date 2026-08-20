# frozen_string_literal: true

RSpec.describe Charming::Components::CommandPaletteModal do
  let(:theme) { Charming::UI::Theme.default }

  it "renders command palette content with default modal chrome" do
    modal = described_class.new(content: "Top\nNew", theme: theme)
    plain = Charming::UI::Width.strip_ansi(modal.render)

    expect(plain).to include("Command palette")
    expect(plain).to include("Type to filter. Enter selects. Escape closes.")
    expect(plain).to include("Top")
    expect(plain).to include("New")
  end

  it "allows modal defaults to be overridden" do
    modal = described_class.new(content: "Body", title: "Commands", help: "Pick one", width: 24, theme: theme)
    plain = Charming::UI::Width.strip_ansi(modal.render)

    expect(plain).to include("Commands")
    expect(plain).to include("Pick one")
    expect(plain).to include("Body")
  end
end
