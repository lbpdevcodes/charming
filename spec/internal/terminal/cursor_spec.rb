# frozen_string_literal: true

RSpec.describe Charming::Internal::Terminal::Cursor do
  it "emits the DECTCEM show sequence" do
    expect(described_class.show).to eq("\e[?25h")
  end

  it "emits the DECTCEM hide sequence" do
    expect(described_class.hide).to eq("\e[?25l")
  end

  it "emits the ED clear-screen sequence" do
    expect(described_class.clear_screen).to eq("\e[2J")
  end

  it "emits CUP cursor positioning as one-based row;column" do
    expect(described_class.move_to(0, 0)).to eq("\e[1;1H")
    expect(described_class.move_to(2, 3)).to eq("\e[4;3H")
  end
end
