# frozen_string_literal: true

RSpec.describe Charming::Components::Table do
  let(:rows) { (1..10).map { |n| ["row#{n}", n.to_s] } }

  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  describe "height windowing" do
    it "renders only the visible window of body rows" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3)
      plain = Charming::UI::Width.strip_ansi(table.render)
      expect(plain).to include("row1")
      expect(plain).to include("row3")
      expect(plain).not_to include("row4")
    end

    it "auto-scrolls to keep the selection in view" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3, selected_index: 6)
      plain = Charming::UI::Width.strip_ansi(table.render)
      expect(plain).to include("row7")
      expect(plain).not_to include("row1")
    end

    it "pages down by one window" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3)
      table.handle_key(key(:page_down))
      expect(table.selected_index).to eq(3)
    end

    it "pages up clamped at the top" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3, selected_index: 1)
      table.handle_key(key(:page_up))
      expect(table.selected_index).to eq(0)
    end

    it "maps clicks through the visible window" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3, selected_index: 6)
      # window starts at row index 4 (rows 5..7 visible); click body row 0 → index 4
      event = Charming::Events::MouseEvent.new(button: 0, x: 1, y: described_class::HEADER_HEIGHT)
      expect(table.handle_mouse(event)).to eq(Charming::Components::Result.handled)
      expect(table.selected_index).to eq(4)
    end

    it "rejects clicks below the visible window" do
      table = described_class.new(header: %w[Name N], rows: rows, height: 3)
      event = Charming::Events::MouseEvent.new(button: 0, x: 1, y: described_class::HEADER_HEIGHT + 5)
      expect(table.handle_mouse(event)).to be_nil
    end
  end
end
