# frozen_string_literal: true

RSpec.describe Charming::Components::HelpOverlay do
  let(:theme) { Charming::UI::Theme.default }

  it "renders bindings as aligned key/description pairs" do
    overlay = described_class.new(bindings: {"q" => "Quit", "ctrl+p" => "Command palette"}, theme: theme)
    plain = Charming::UI::Width.strip_ansi(overlay.render)
    expect(plain).to include("q")
    expect(plain).to include("Quit")
    expect(plain).to include("ctrl+p")
    expect(plain).to include("Command palette")
    expect(plain).to include("Keyboard Shortcuts")
  end

  it "dismisses on any key" do
    overlay = described_class.new(bindings: {})
    event = Charming::Events::KeyEvent.new(key: :x)
    expect(overlay.handle_key(event)).to eq(Charming::Components::Result.cancelled)
  end

  it "builds from a controller class's key bindings" do
    controller_class = Class.new(Charming::Controller) do
      key "q", :quit
      key "o", :open_command_palette
      def show = render("")
    end
    stub_const("HelpOverlaySpecController", controller_class)

    overlay = described_class.for_controller(HelpOverlaySpecController, theme: theme)
    plain = Charming::UI::Width.strip_ansi(overlay.render)
    expect(plain).to include("Quit")
    expect(plain).to include("Open command palette")
  end

  it "renders a notice when there are no bindings" do
    overlay = described_class.new(bindings: {}, theme: theme)
    expect(Charming::UI::Width.strip_ansi(overlay.render)).to include("No key bindings")
  end
end
