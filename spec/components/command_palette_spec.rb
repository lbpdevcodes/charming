# frozen_string_literal: true

RSpec.describe Charming::Components::CommandPalette do
  def key(name, char: nil)
    Charming::Events::KeyEvent.new(key: name, char: char)
  end

  def command(label, value = label.downcase.tr(" ", "_"))
    described_class::Command.new(label: label, value: value)
  end

  def selected(value)
    "\e[1;38;2;159;232;176;48;2;24;35;61m#{value}\e[0m"
  end

  it "renders the search input and command list" do
    palette = described_class.new(commands: [command("Open File"), command("Quit")])

    expect(palette.render).to eq("|Search commands\n#{selected("> Open File")}\n  Quit")
  end

  it "filters commands as the user types" do
    palette = described_class.new(commands: [command("Open File"), command("Quit")])

    expect(palette.handle_key(key(:q, char: "q"))).to eq(Charming::Components::Result.handled)

    expect(palette.render).to eq("q|\n#{selected("> Quit")}")
    expect(palette.selected_command.label).to eq("Quit")
  end

  it "moves the selected command down and up" do
    palette = described_class.new(commands: [command("Open"), command("Run"), command("Quit")])

    expect(palette.handle_key(key(:down))).to eq(Charming::Components::Result.handled)
    palette.handle_key(key(:down))
    palette.handle_key(key(:up))

    expect(palette.selected_command.label).to eq("Run")
  end

  it "returns the selected command on enter" do
    quit = command("Quit")
    palette = described_class.new(commands: [command("Open"), quit])

    palette.handle_key(key(:down))

    expect(palette.handle_key(key(:enter))).to eq(Charming::Components::Result.selected(quit))
  end

  it "returns Result.cancelled on escape" do
    palette = described_class.new(commands: [command("Open")])

    expect(palette.handle_key(key(:escape))).to eq(Charming::Components::Result.cancelled)
  end

  it "initializes from primitive state" do
    palette = described_class.new(
      commands: [command("Open"), command("Quit")],
      value: "qu",
      cursor: 1,
      selected_index: 0
    )

    expect(palette.render).to eq("q|u\n#{selected("> Quit")}")
    expect(palette.selected_command.label).to eq("Quit")
  end

  it "exposes primitive state after input and selection changes" do
    palette = described_class.new(commands: [command("Open"), command("Run"), command("Read")])

    palette.handle_key(key(:r, char: "r"))
    palette.handle_key(key(:down))

    expect(palette.state).to eq(value: "r", cursor: 1, selected_index: 1)
  end

  it "renders an empty state when no commands match" do
    palette = described_class.new(commands: [command("Open")])

    palette.handle_key(key(:z, char: "z"))

    expect(palette.render).to eq("z|\nNo commands found")
    expect(palette.selected_command).to be_nil
  end
end
