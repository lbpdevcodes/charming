# frozen_string_literal: true

RSpec.describe Charming::Components::List do
  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  it "selects the first item by default" do
    list = described_class.new(items: %w[Open Quit])

    expect(list.selected_index).to eq(0)
    expect(list.selected_item).to eq("Open")
  end

  it "moves selection down and up" do
    list = described_class.new(items: %w[Open Run Quit])

    expect(list.handle_key(key(:down))).to eq(Charming::Components::Result.handled)
    list.handle_key(key(:down))
    list.handle_key(key(:up))

    expect(list.selected_index).to eq(1)
    expect(list.selected_item).to eq("Run")
  end

  it "supports vim navigation keys by default" do
    list = described_class.new(items: %w[Open Run Quit])

    expect(list.handle_key(key(:j))).to eq(Charming::Components::Result.handled)
    list.handle_key(key(:k))

    expect(list.selected_index).to eq(0)
  end

  it "allows vim navigation keys to be disabled" do
    list = described_class.new(items: %w[Open Run Quit], keymap: nil)

    expect(list.handle_key(key(:j))).to be_nil
    expect(list.selected_index).to eq(0)
  end

  it "supports custom navigation keymaps" do
    list = described_class.new(items: %w[Open Run Quit], keymap: {down: :s})

    expect(list.handle_key(key(:s))).to eq(Charming::Components::Result.handled)
    expect(list.selected_index).to eq(1)
  end

  it "clamps movement at list boundaries" do
    list = described_class.new(items: %w[Open Quit])

    list.handle_key(key(:up))
    expect(list.selected_index).to eq(0)

    list.handle_key(key(:down))
    list.handle_key(key(:down))
    expect(list.selected_index).to eq(1)
  end

  it "moves selection home and end" do
    list = described_class.new(items: %w[Open Run Quit], selected_index: 1)

    list.handle_key(key(:end))
    expect(list.selected_item).to eq("Quit")

    list.handle_key(key(:home))
    expect(list.selected_item).to eq("Open")
  end

  it "returns the selected item on enter" do
    list = described_class.new(items: %w[Open Quit], selected_index: 1)

    expect(list.handle_key(key(:enter))).to eq(Charming::Components::Result.selected("Quit"))
  end

  it "ignores unsupported keys" do
    list = described_class.new(items: %w[Open Quit])

    expect(list.handle_key(key(:left))).to be_nil
  end

  it "renders the selected item highlighted" do
    list = described_class.new(items: %w[Open Quit])

    expect(list.render).to eq("\e[1;38;2;159;232;176;48;2;24;35;61m> Open\e[0m\n  Quit")
  end

  it "supports custom item labels" do
    command = Struct.new(:name)
    list = described_class.new(items: [command.new("Open File")], label: :name.to_proc)

    expect(list.render).to eq("\e[1;38;2;159;232;176;48;2;24;35;61m> Open File\e[0m")
  end

  it "renders a viewport around the selected item" do
    list = described_class.new(items: %w[One Two Three Four], selected_index: 2, height: 2)

    expect(list.render).to eq("  Two\n\e[1;38;2;159;232;176;48;2;24;35;61m> Three\e[0m")
  end

  it "handles mouse click selection within viewport" do
    list = described_class.new(items: %w[One Two Three Four Five], selected_index: 0, height: 3)

    mouse = Charming::Events::MouseEvent.new(button: 0, x: 5, y: 2)
    expect(list.handle_mouse(mouse)).to eq(Charming::Components::Result.handled)
    expect(list.selected_index).to eq(2)
  end

  it "ignores mouse clicks outside viewport" do
    list = described_class.new(items: %w[One Two Three Four Five], selected_index: 0, height: 3)

    mouse = Charming::Events::MouseEvent.new(button: 0, x: 5, y: 10)
    expect(list.handle_mouse(mouse)).to be_nil
    expect(list.selected_index).to eq(0)
  end

  it "ignores mouse scroll events" do
    list = described_class.new(items: %w[One Two Three])

    mouse = Charming::Events::MouseEvent.new(button: 64, x: 0, y: 0)
    expect(list.handle_mouse(mouse)).to be_nil
  end

  it "ignores mouse when no height is set" do
    list = described_class.new(items: %w[One Two Three])

    mouse = Charming::Events::MouseEvent.new(button: 0, x: 0, y: 1)
    expect(list.handle_mouse(mouse)).to be_nil
  end

  describe "#items=" do
    it "replaces the items while keeping a valid selection" do
      list = described_class.new(items: %w[Alpha Beta Gamma], selected_index: 1)

      list.items = %w[Delta Epsilon]

      expect(list.items).to eq(%w[Delta Epsilon])
      expect(list.selected_item).to eq("Epsilon")
    end

    it "clamps the selection when the new list is shorter" do
      list = described_class.new(items: %w[Alpha Beta Gamma], selected_index: 2)

      list.items = %w[Delta]

      expect(list.selected_item).to eq("Delta")
    end

    it "resets the selection when the new list is empty" do
      list = described_class.new(items: %w[Alpha Beta], selected_index: 1)

      list.items = []

      expect(list.selected_item).to be_nil
      expect(list.selected_index).to eq(0)
    end

    it "re-applies the active filter to the new items" do
      list = described_class.new(items: %w[Alpha Beta], filter: "alp")

      list.items = %w[Alpine Beta]

      expect(list.items).to eq(%w[Alpine])
    end
  end

  describe "filtering" do
    it "narrows items with fuzzy matching, best match first" do
      list = described_class.new(items: ["Open palette", "Close panel", "Save file"], filter: "pal")

      expect(list.items).to eq(["Open palette", "Close panel"])
      expect(list.selected_item).to eq("Open palette")
    end

    it "navigates and selects within the filtered view" do
      list = described_class.new(items: ["Open palette", "Close panel", "Save file"], filter: "pal")

      list.handle_key(Charming::Events::KeyEvent.new(key: :down))

      expect(list.selected_item).to eq("Close panel")
    end

    it "updates the filter after construction, reclamping the selection" do
      list = described_class.new(items: %w[Alpha Beta Gamma], selected_index: 2)

      list.filter = "beta"

      expect(list.items).to eq(%w[Beta])
      expect(list.selected_item).to eq("Beta")
    end

    it "clears the filter with nil" do
      list = described_class.new(items: %w[Alpha Beta], filter: "beta")

      list.filter = nil

      expect(list.items).to eq(%w[Alpha Beta])
    end

    it "matches against the custom label" do
      item = Struct.new(:name)
      list = described_class.new(items: [item.new("Ruby"), item.new("Go")], filter: "go", label: :name.to_proc)

      expect(list.items.map(&:name)).to eq(%w[Go])
    end

    it "renders only the filtered items" do
      list = described_class.new(items: %w[Alpha Beta], filter: "beta")

      expect(list.render).not_to include("Alpha")
    end
  end
end
