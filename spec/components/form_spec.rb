# frozen_string_literal: true

RSpec.describe Charming::Components::Form do
  let(:theme) { Charming::UI::Theme.default }

  def key(name, char: nil, shift: false, ctrl: false)
    Charming::Events::KeyEvent.new(key: name, char: char, shift: shift, ctrl: ctrl)
  end

  def plain(value)
    value.gsub(/\e\[[0-9;]*m/, "")
  end

  it "renders input, select, confirm, and note fields" do
    form = described_class.new(
      fields: [
        described_class::Input.new(:name, placeholder: "Ada", theme: theme),
        described_class::Textarea.new(:bio, placeholder: "Bio", height: 2, theme: theme),
        described_class::Select.new(:plan, options: %w[Free Pro], theme: theme),
        described_class::Confirm.new(:terms, label: "Accept terms?", theme: theme),
        described_class::Note.new("Escape cancels", theme: theme)
      ],
      state: {},
      theme: theme
    )

    rendered = plain(form.render)

    expect(rendered).to include("> Name: |Ada")
    expect(rendered).to include("  Bio:")
    expect(rendered).to include("  |Bio")
    expect(rendered).to include("  Plan: Free")
    expect(rendered).to include("  [ ] Accept terms?")
    expect(rendered).to include("Escape cancels")
  end

  it "humanizes default field labels" do
    form = described_class.new(fields: [described_class::Input.new(:first_name, theme: theme)], state: {}, theme: theme)

    expect(plain(form.render)).to include("First name:")
  end

  it "stores input value and cursor in primitive state" do
    state = {}
    form = described_class.new(fields: [described_class::Input.new(:name)], state: state)

    expect(form.handle_key(key(:a, char: "a"))).to eq(Charming::Components::Result.handled)

    expect(state[:values]).to eq(name: "a")
    expect(state[:fields]).to eq(name: {cursor: 1})
    expect(plain(described_class.new(fields: [described_class::Input.new(:name, theme: theme)], state: state, theme: theme).render)).to include("a|")
  end

  it "stores select choice and selected index in primitive state" do
    state = {}
    form = described_class.new(fields: [described_class::Select.new(:plan, options: %w[Free Pro Team])], state: state)

    expect(form.handle_key(key(:down))).to eq(Charming::Components::Result.handled)

    expect(state[:values]).to eq(plan: "Pro")
    expect(state[:fields]).to eq(plan: {selected_index: 1})
    expect(plain(described_class.new(fields: [described_class::Select.new(:plan, options: %w[Free Pro Team], theme: theme)], state: state, theme: theme).render)).to include("Plan: Pro")
  end

  it "toggles multiselect checkboxes with space and stores the checked set" do
    state = {}
    form = described_class.new(
      fields: [described_class::Multiselect.new(:tags, options: %w[ruby go rust])],
      state: state
    )

    expect(form.handle_key(key(:space, char: " "))).to eq(Charming::Components::Result.handled)
    expect(form.handle_key(key(:down))).to eq(Charming::Components::Result.handled)
    expect(form.handle_key(key(:space, char: " "))).to eq(Charming::Components::Result.handled)

    expect(state[:values]).to eq(tags: %w[ruby go])
    expect(state[:fields]).to eq(tags: {selected_indices: [0, 1], cursor: 1})
    rerendered = described_class.new(
      fields: [described_class::Multiselect.new(:tags, options: %w[ruby go rust], theme: theme)],
      state: state,
      theme: theme
    )
    expect(plain(rerendered.render)).to include("Tags: ruby, go")
  end

  it "submits a multiselect field's checked set on enter" do
    state = {}
    form = described_class.new(
      fields: [described_class::Multiselect.new(:tags, options: %w[ruby go])],
      state: state
    )

    form.handle_key(key(:space, char: " "))

    expect(form.handle_key(key(:enter))).to eq(Charming::Components::Result.submitted({tags: %w[ruby]}))
  end

  it "caps multiselect checks at max_selections" do
    state = {}
    form = described_class.new(
      fields: [described_class::Multiselect.new(:tags, options: %w[a b], max_selections: 1)],
      state: state
    )

    form.handle_key(key(:space, char: " "))
    form.handle_key(key(:down))
    form.handle_key(key(:space, char: " "))

    expect(state[:values]).to eq(tags: %w[a])
  end

  it "declares multiselect fields through the builder" do
    builder = described_class::Builder.new
    builder.multiselect(:tags, options: %w[a b])

    expect(builder.fields.last).to be_a(described_class::Multiselect)
  end

  it "stores textarea value, cursor, and offset in primitive state" do
    state = {}
    form = described_class.new(fields: [described_class::Textarea.new(:bio, height: 2)], state: state)

    form.handle_key(key(:a, char: "a"))
    form.handle_key(key(:enter, char: "\n", shift: true))
    form.handle_key(key(:b, char: "b"))

    expect(state[:values]).to eq(bio: "a\nb")
    expect(state[:fields]).to eq(bio: {cursor: 3, offset: 0, preferred_column: 1})
    expect(plain(described_class.new(fields: [described_class::Textarea.new(:bio, height: 2, theme: theme)], state: state, theme: theme).render)).to include("  b|")
  end

  it "inserts a newline on plain enter in a textarea (leave the field with tab)" do
    state = {}
    form = described_class.new(
      fields: [described_class::Textarea.new(:bio), described_class::Input.new(:name)],
      state: state
    )

    expect(form.handle_key(key(:enter, char: "\n"))).to eq(Charming::Components::Result.handled)
    expect(state[:focus_index]).to eq(0)
    expect(state[:values][:bio]).to eq("\n")

    expect(form.handle_key(key(:tab))).to eq(Charming::Components::Result.handled)
    expect(state[:focus_index]).to eq(1)
  end

  it "creates a blank line from two enters in a textarea" do
    state = {}
    form = described_class.new(fields: [described_class::Textarea.new(:bio)], state: state)

    form.handle_key(key(:a, char: "a"))
    2.times { form.handle_key(key(:enter, char: "\n")) }
    form.handle_key(key(:b, char: "b"))

    expect(state[:values][:bio]).to eq("a\n\nb")
  end

  it "inserts textarea newlines with shift-enter, ctrl-j, and ctrl-n" do
    state = {}
    form = described_class.new(fields: [described_class::Textarea.new(:bio)], state: state)

    expect(form.handle_key(key(:enter, char: "\n", shift: true))).to eq(Charming::Components::Result.handled)
    expect(form.handle_key(key(:j, ctrl: true))).to eq(Charming::Components::Result.handled)
    expect(form.handle_key(key(:n, ctrl: true))).to eq(Charming::Components::Result.handled)

    expect(state[:values][:bio]).to eq("\n\n\n")
  end

  it "submits with ctrl-s from a textarea" do
    state = {values: {bio: "hello"}}
    form = described_class.new(fields: [described_class::Textarea.new(:bio)], state: state)

    expect(form.handle_key(key(:s, ctrl: true))).to eq(Charming::Components::Result.submitted({bio: "hello"}))
  end

  it "toggles confirm fields with space and y/n keys" do
    state = {}
    form = described_class.new(fields: [described_class::Confirm.new(:terms)], state: state)

    expect(form.handle_key(key(:space))).to eq(Charming::Components::Result.handled)
    expect(state[:values][:terms]).to eq(true)

    form.handle_key(key(:n, char: "n"))
    expect(state[:values][:terms]).to eq(false)

    form.handle_key(key(:y, char: "y"))
    expect(state[:values][:terms]).to eq(true)
  end

  it "moves focus with tab and shift-tab" do
    state = {}
    form = described_class.new(
      fields: [described_class::Input.new(:name), described_class::Confirm.new(:terms)],
      state: state
    )

    expect(form.handle_key(key(:tab))).to eq(Charming::Components::Result.handled)
    expect(state[:focus_index]).to eq(1)

    form.handle_key(key(:tab, shift: true))
    expect(state[:focus_index]).to eq(0)
  end

  it "advances on enter and submits from the last focusable field" do
    state = {values: {name: "Ada"}}
    form = described_class.new(
      fields: [described_class::Input.new(:name), described_class::Confirm.new(:terms, value: true)],
      state: state
    )

    expect(form.handle_key(key(:enter))).to eq(Charming::Components::Result.handled)
    expect(state[:focus_index]).to eq(1)

    expect(form.handle_key(key(:enter))).to eq(Charming::Components::Result.submitted({name: "Ada", terms: true}))
  end

  it "renders validation errors instead of submitting invalid values" do
    state = {}
    form = described_class.new(fields: [described_class::Input.new(:name, required: true, theme: theme)], state: state, theme: theme)

    expect(form.handle_key(key(:enter))).to eq(Charming::Components::Result.handled)

    expect(state[:errors]).to eq(name: ["is required"])
    expect(plain(form.render)).to include("is required")
  end

  it "treats whitespace-only textarea values as invalid when required" do
    state = {values: {bio: "  \n  "}}
    form = described_class.new(fields: [described_class::Textarea.new(:bio, required: true)], state: state)

    expect(form.handle_key(key(:s, ctrl: true))).to eq(Charming::Components::Result.handled)

    expect(state[:errors]).to eq(bio: ["is required"])
  end

  it "returns Result.cancelled on escape" do
    form = described_class.new(fields: [described_class::Input.new(:name)], state: {})

    expect(form.handle_key(key(:escape))).to eq(Charming::Components::Result.cancelled)
  end

  it "inserts pasted text into the focused input field and persists it to state" do
    state = {}
    form = described_class.new(fields: [described_class::Input.new(:name, value: "ab")], state: state)

    expect(form.handle_paste(Charming::Events::PasteEvent.new(text: "XY"))).to eq(Charming::Components::Result.handled)

    expect(state[:values]).to eq(name: "abXY")
    expect(state[:fields]).to eq(name: {cursor: 4})
  end

  it "keeps newlines when pasting into the focused textarea field" do
    state = {}
    form = described_class.new(fields: [described_class::Textarea.new(:bio)], state: state)

    expect(form.handle_paste(Charming::Events::PasteEvent.new(text: "line one\r\nline two"))).to eq(Charming::Components::Result.handled)

    expect(state[:values]).to eq(bio: "line one\nline two")
    expect(state[:fields][:bio]).to include(cursor: 17)
  end

  it "ignores paste when a non-text field is focused" do
    state = {}
    form = described_class.new(fields: [described_class::Select.new(:plan, options: %w[Free Pro])], state: state)

    expect(form.handle_paste(Charming::Events::PasteEvent.new(text: "XY"))).to be_nil

    expect(state[:values]).to eq(plan: "Free")
  end
end
