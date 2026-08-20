# frozen_string_literal: true

RSpec.describe Charming::Components::Autocomplete do
  let(:suggestions) { %w[ruby rails rspec python] }

  def key(name, char: nil)
    Charming::Events::KeyEvent.new(key: name, char: char)
  end

  it "shows all suggestions when the value is empty" do
    combo = described_class.new(suggestions: suggestions)
    expect(combo.filtered_suggestions).to eq(suggestions)
  end

  it "filters suggestions by substring" do
    combo = described_class.new(suggestions: suggestions, value: "r")
    expect(combo.filtered_suggestions).to eq(%w[ruby rails rspec])
  end

  it "caps the suggestion list" do
    combo = described_class.new(suggestions: suggestions, max_suggestions: 2)
    expect(combo.filtered_suggestions.length).to eq(2)
  end

  it "moves the highlight with up/down" do
    combo = described_class.new(suggestions: suggestions)
    combo.handle_key(key(:down))
    expect(combo.selected_index).to eq(1)
    combo.handle_key(key(:up))
    expect(combo.selected_index).to eq(0)
  end

  it "submits the highlighted suggestion on enter" do
    combo = described_class.new(suggestions: suggestions, value: "ra")
    expect(combo.handle_key(key(:enter))).to eq([:submitted, "rails"])
  end

  it "submits free text when nothing matches" do
    combo = described_class.new(suggestions: suggestions, value: "zig")
    expect(combo.handle_key(key(:enter))).to eq([:submitted, "zig"])
  end

  it "cancels on escape" do
    combo = described_class.new(suggestions: suggestions)
    expect(combo.handle_key(key(:escape))).to eq(:cancelled)
  end

  it "types into the inner input and re-filters" do
    combo = described_class.new(suggestions: suggestions)
    combo.handle_key(key(:p, char: "p"))
    expect(combo.value).to eq("p")
    expect(combo.filtered_suggestions).to eq(%w[rspec python])
  end

  it "inserts pasted text and re-filters suggestions" do
    combo = described_class.new(suggestions: suggestions, value: "r", selected_index: 2)
    expect(combo.handle_paste(Charming::Events::PasteEvent.new(text: "spe"))).to eq(:handled)
    expect(combo.value).to eq("rspe")
    expect(combo.filtered_suggestions).to eq(%w[rspec])
    expect(combo.selected_index).to eq(0)
  end

  it "renders the input line and suggestions" do
    combo = described_class.new(suggestions: suggestions, value: "ru")
    plain = Charming::UI::Width.strip_ansi(combo.render)
    expect(plain).to include("ru|")
    expect(plain).to include("ruby")
  end

  describe "#suggestions=" do
    it "replaces the suggestions and clamps the selection" do
      combo = described_class.new(suggestions: %w[alpha beta gamma], value: "", selected_index: 2)

      combo.suggestions = %w[delta]

      expect(combo.selected_index).to eq(0)
      expect(Charming::UI::Width.strip_ansi(combo.render)).to include("delta")
      expect(Charming::UI::Width.strip_ansi(combo.render)).not_to include("alpha")
    end
  end
end
