# frozen_string_literal: true

RSpec.describe Charming::Components::MultiSelectList do
  let(:items) { %w[ruby rails rspec] }

  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  it "renders unchecked boxes by default" do
    list = described_class.new(items: items)
    plain = Charming::UI::Width.strip_ansi(list.render)
    expect(plain.lines.first).to include("[ ] ruby")
  end

  it "toggles the highlighted item with space" do
    list = described_class.new(items: items)
    expect(list.handle_key(key(:space))).to eq(:handled)
    expect(Charming::UI::Width.strip_ansi(list.render)).to include("[x] ruby")
  end

  it "untoggles on second space" do
    list = described_class.new(items: items)
    list.handle_key(key(:space))
    list.handle_key(key(:space))
    expect(list.selected_items).to be_empty
  end

  it "navigates with arrows and toggles different items" do
    list = described_class.new(items: items)
    list.handle_key(key(:space))
    list.handle_key(key(:down))
    list.handle_key(key(:space))
    expect(list.selected_items).to eq(%w[ruby rails])
  end

  it "returns [:submitted, items] on enter" do
    list = described_class.new(items: items, selected_indices: [0, 2])
    expect(list.handle_key(key(:enter))).to eq([:submitted, %w[ruby rspec]])
  end

  it "enforces max_selections" do
    list = described_class.new(items: items, max_selections: 1)
    list.handle_key(key(:space))
    list.handle_key(key(:down))
    list.handle_key(key(:space))
    expect(list.selected_items).to eq(%w[ruby])
  end

  it "restores selected_indices from initialization" do
    list = described_class.new(items: items, selected_indices: [1])
    expect(list.selected_items).to eq(%w[rails])
  end

  it "discards out-of-range initial indices" do
    list = described_class.new(items: items, selected_indices: [0, 99])
    expect(list.selected_items).to eq(%w[ruby])
  end

  describe "#items=" do
    it "replaces items, keeps in-range checks, and drops out-of-range ones" do
      list = described_class.new(items: items, selected_indices: [0, 2])

      list.items = %w[alpha beta]

      expect(list.selected_items).to eq(%w[alpha])
    end

    it "keeps the highlight valid when the new list is shorter" do
      list = described_class.new(items: items, selected_index: 2)

      list.items = %w[alpha]

      expect(list.selected_index).to eq(0)
    end
  end
end
