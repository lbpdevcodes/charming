# frozen_string_literal: true

require "tmpdir"

RSpec.describe Charming::Components::Filepicker do
  def key(name, char: nil)
    Charming::Events::KeyEvent.new(key: name, char: char)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      FileUtils.mkdir_p(File.join(dir, "docs"))
      File.write(File.join(dir, "README.md"), "hi")
      File.write(File.join(dir, "docs", "guide.md"), "hi")
      File.write(File.join(dir, ".secret"), "hi")
      example.run
    end
  end

  it "lists directories first, then files, hiding dotfiles by default" do
    picker = described_class.new(root: @root)

    expect(picker.entries).to eq(["docs/", "README.md"])
  end

  it "shows hidden files when toggled" do
    picker = described_class.new(root: @root)

    picker.toggle_hidden

    expect(picker.entries).to include(".secret")
  end

  it "descends into a directory on enter and lists a parent entry" do
    picker = described_class.new(root: @root)

    expect(picker.handle_key(key(:enter))).to eq(Charming::Components::Result.handled)
    expect(picker.current_dir).to eq(File.join(@root, "docs"))
    expect(picker.entries).to eq(["../", "guide.md"])
  end

  it "returns the selected file's absolute path on enter" do
    picker = described_class.new(root: @root)

    picker.handle_key(key(:down))

    expect(picker.handle_key(key(:enter))).to eq(Charming::Components::Result.selected(File.join(@root, "README.md")))
  end

  it "goes up a directory on backspace, but never above the root" do
    picker = described_class.new(root: @root)

    picker.handle_key(key(:enter))
    expect(picker.handle_key(key(:backspace))).to eq(Charming::Components::Result.handled)
    expect(picker.current_dir).to eq(@root)

    expect(picker.handle_key(key(:backspace))).to be_nil
    expect(picker.current_dir).to eq(@root)
  end

  it "ascends through the parent entry" do
    picker = described_class.new(root: @root)

    picker.handle_key(key(:enter))
    picker.handle_key(key(:enter))

    expect(picker.current_dir).to eq(@root)
  end

  it "renders the listing with the selection marker" do
    picker = described_class.new(root: @root, theme: Charming::UI::Theme.default)

    plain = picker.render.gsub(/\e\[[0-9;]*m/, "")
    expect(plain).to eq("> docs/\n  README.md")
  end
end
