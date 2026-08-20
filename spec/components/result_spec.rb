# frozen_string_literal: true

RSpec.describe Charming::Components::Result do
  describe "factories" do
    it "carries kind and value" do
      expect(described_class.submitted("x")).to eq(described_class.new(kind: :submitted, value: "x"))
      expect(described_class.selected(42).value).to eq(42)
      expect(described_class.cancelled.kind).to eq(:cancelled)
      expect(described_class.handled.kind).to eq(:handled)
      expect(described_class.changed("y").value).to eq("y")
    end

    it "answers kind predicates" do
      expect(described_class.submitted("x").submitted?).to be true
      expect(described_class.selected(1).selected?).to be true
      expect(described_class.cancelled.cancelled?).to be true
      expect(described_class.handled.handled?).to be true
      expect(described_class.changed(1).changed?).to be true
      expect(described_class.handled.submitted?).to be false
    end
  end

  describe ".normalize" do
    it "passes Results through unchanged" do
      result = described_class.selected(1)
      expect(described_class.normalize(result)).to equal(result)
    end

    it "normalizes the legacy forms" do
      expect(described_class.normalize(:handled)).to eq(described_class.handled)
      expect(described_class.normalize(:cancelled)).to eq(described_class.cancelled)
      expect(described_class.normalize([:submitted, "v"])).to eq(described_class.submitted("v"))
      expect(described_class.normalize([:selected, 7])).to eq(described_class.selected(7))
    end

    it "passes nil through" do
      expect(described_class.normalize(nil)).to be_nil
    end
  end
end
