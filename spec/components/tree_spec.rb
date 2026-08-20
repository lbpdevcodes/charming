# frozen_string_literal: true

RSpec.describe Charming::Components::Tree do
  let(:nodes) do
    [
      {label: "src", expanded: true, children: [
        {label: "main.rb"},
        {label: "lib", children: [{label: "util.rb"}]}
      ]},
      {label: "README.md"}
    ]
  end

  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  it "renders expanded branches with their children" do
    tree = described_class.new(nodes: nodes)
    plain = Charming::UI::Width.strip_ansi(tree.render)
    expect(plain).to include("▾ src")
    expect(plain).to include("main.rb")
    expect(plain).to include("▸ lib")
    expect(plain).to include("README.md")
  end

  it "hides children of collapsed branches" do
    tree = described_class.new(nodes: nodes)
    plain = tree.render
    expect(plain).not_to include("util.rb")
  end

  it "indents children by depth" do
    tree = described_class.new(nodes: nodes)
    lines = Charming::UI::Width.strip_ansi(tree.render).lines
    expect(lines[1]).to start_with("  ") # main.rb is one level deep
  end

  it "navigates up and down through visible nodes" do
    tree = described_class.new(nodes: nodes)
    tree.handle_key(key(:down))
    expect(tree.current_node[:label]).to eq("main.rb")
  end

  it "expands a collapsed branch with right" do
    tree = described_class.new(nodes: nodes, cursor_index: 2) # "lib"
    tree.handle_key(key(:right))
    expect(tree.render).to include("util.rb")
  end

  it "collapses an expanded branch with left" do
    tree = described_class.new(nodes: nodes)
    tree.handle_key(key(:left))
    expect(tree.render).not_to include("main.rb")
  end

  it "jumps to the parent with left on a leaf" do
    tree = described_class.new(nodes: nodes, cursor_index: 1) # main.rb
    tree.handle_key(key(:left))
    expect(tree.current_node[:label]).to eq("src")
  end

  it "returns [:selected, node] on enter for a leaf" do
    tree = described_class.new(nodes: nodes, cursor_index: 1)
    result = tree.handle_key(key(:enter))
    expect(result.first).to eq(:selected)
    expect(result.last[:label]).to eq("main.rb")
  end

  it "toggles a branch on enter" do
    tree = described_class.new(nodes: nodes) # cursor on src
    expect(tree.handle_key(key(:enter))).to eq(:handled)
    expect(tree.render).not_to include("main.rb")
  end

  it "toggles a branch on click" do
    tree = described_class.new(nodes: nodes)
    event = Charming::Events::MouseEvent.new(button: 0, x: 0, y: 0)
    expect(tree.handle_mouse(event)).to eq(:handled)
    expect(tree.render).not_to include("main.rb")
  end

  it "windows long trees to the configured height" do
    tree = described_class.new(nodes: nodes, height: 2)
    expect(tree.render.lines.length).to eq(2)
  end

  it "handles an empty tree" do
    tree = described_class.new(nodes: [])
    expect(tree.render).to eq("")
    expect(tree.handle_key(key(:enter))).to be_nil
  end

  describe "#nodes=" do
    it "replaces the root nodes and clamps the cursor into range" do
      tree = described_class.new(nodes: nodes, cursor_index: 3)
      expect(tree.current_node).to eq({label: "README.md"})

      tree.nodes = [{label: "only.rb"}]

      expect(tree.nodes).to eq([{label: "only.rb"}])
      expect(tree.current_node).to eq({label: "only.rb"})
    end
  end
end
