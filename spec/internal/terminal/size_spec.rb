# frozen_string_literal: true

RSpec.describe Charming::Internal::Terminal::Size do
  it "measures a TTY via IO#winsize as [width, height]" do
    io = instance_double(IO, winsize: [24, 80])

    expect(described_class.measure(io, env: {})).to eq([80, 24])
  end

  it "prefers the first TTY among the IOs" do
    plain = instance_double(IO, winsize: nil)
    tty = instance_double(IO, winsize: [40, 120])

    expect(described_class.measure(plain, tty, env: {})).to eq([120, 40])
  end

  it "falls back to ENV COLUMNS/LINES when no IO reports a size" do
    io = instance_double(IO, winsize: nil)

    expect(described_class.measure(io, env: {"COLUMNS" => "100", "LINES" => "30"})).to eq([100, 30])
  end

  it "skips IOs that do not respond to winsize and ones that raise" do
    raising = instance_double(IO)
    allow(raising).to receive(:winsize).and_raise(SystemCallError, "not a terminal")

    expect(described_class.measure(Object.new, raising, env: {})).to eq([80, 24])
  end

  it "defaults to 80x24 when nothing reports a size" do
    expect(described_class.measure(env: {})).to eq([80, 24])
  end
end
