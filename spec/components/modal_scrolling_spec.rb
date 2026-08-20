# frozen_string_literal: true

RSpec.describe Charming::Components::Modal do
  let(:long_content) { (1..20).map { |n| "line #{n}" }.join("\n") }

  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  describe "scrollable body" do
    it "windows the body to max_body_height" do
      modal = described_class.new(content: long_content, max_body_height: 5)
      plain = Charming::UI::Width.strip_ansi(modal.render)
      expect(plain).to include("line 1")
      expect(plain).not_to include("line 6")
    end

    it "scrolls down on key events and exposes the offset" do
      modal = described_class.new(content: long_content, max_body_height: 5)
      expect(modal.handle_key(key(:down))).to eq(Charming::Components::Result.handled)
      expect(modal.scroll_offset).to eq(1)
    end

    it "restores a prior scroll offset" do
      modal = described_class.new(content: long_content, max_body_height: 5, scroll_offset: 10)
      plain = Charming::UI::Width.strip_ansi(modal.render)
      expect(plain).to include("line 11")
      expect(plain).not_to include("line 1\n")
    end

    it "does not consume keys when the body fits" do
      modal = described_class.new(content: "short", max_body_height: 5)
      expect(modal.handle_key(key(:down))).to be_nil
    end

    it "does not consume keys when no max_body_height is set" do
      modal = described_class.new(content: long_content)
      expect(modal.handle_key(key(:down))).to be_nil
    end
  end
end
