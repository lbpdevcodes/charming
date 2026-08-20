# frozen_string_literal: true

require "tmpdir"

# Acceptance: every interactive built-in component speaks the Result protocol.
# Each entry builds a minimal component and feeds it a battery of key, mouse, and
# paste events. Every non-nil return from handle_key/handle_mouse/handle_paste must
# be a Charming::Components::Result; nil remains a legitimate "not consumed" return.
RSpec.describe "component Result protocol" do
  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  def click(x: 0, y: 0)
    Charming::Events::MouseEvent.new(button: 0, x: x, y: y)
  end

  def paste
    Charming::Events::PasteEvent.new(text: "hi")
  end

  # The state hash a Form field expects to be bound to.
  def field_state
    {values: {}, fields: {}, errors: {}}
  end

  def bound(field)
    field.bind(field_state)
    field
  end

  around do |example|
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "docs"))
      File.write(File.join(dir, "file.txt"), "hi")
      @picker_root = dir
      example.run
    end
  end

  # name, builder, and (where the default origin click misses) a mouse event.
  cases = [
    ["TextInput", -> { Charming::Components::TextInput.new }, nil],
    ["TextArea", -> { Charming::Components::TextArea.new }, nil],
    ["List", -> { Charming::Components::List.new(items: %w[a b c], height: 3) }, nil],
    ["MultiSelectList", -> { Charming::Components::MultiSelectList.new(items: %w[a b c]) }, nil],
    ["Table", -> { Charming::Components::Table.new(header: %w[name], rows: [["a"], ["b"]]) },
      -> { click(y: Charming::Components::Table::HEADER_HEIGHT) }],
    ["Tree", -> { Charming::Components::Tree.new(nodes: [{label: "root", expanded: true, children: [{label: "leaf"}]}]) }, nil],
    ["TabBar", -> { Charming::Components::TabBar.new(tabs: %w[one two]) }, nil],
    ["Autocomplete", -> { Charming::Components::Autocomplete.new(suggestions: %w[ruby rails]) }, nil],
    ["CommandPalette", -> {
      Charming::Components::CommandPalette.new(commands: [
        Charming::Components::CommandPalette::Command.new(label: "Quit", value: :quit)
      ])
    }, nil],
    ["Viewport", -> { Charming::Components::Viewport.new(content: "one\ntwo\nthree\nfour\nfive", height: 2) }, nil],
    ["Modal", -> { Charming::Components::Modal.new(content: "l1\nl2\nl3\nl4\nl5", max_body_height: 2) }, nil],
    ["HelpOverlay", -> { Charming::Components::HelpOverlay.new(bindings: {"q" => "Quit"}) }, nil],
    ["Form", -> {
      Charming::Components::Form.new(fields: [Charming::Components::Form::Input.new(:name)], state: {})
    }, nil],
    ["Form::Input", -> { bound(Charming::Components::Form::Input.new(:name)) }, nil],
    ["Form::Textarea", -> { bound(Charming::Components::Form::Textarea.new(:bio)) }, nil],
    ["Form::Confirm", -> { bound(Charming::Components::Form::Confirm.new(:terms)) }, nil],
    ["Form::Select", -> { bound(Charming::Components::Form::Select.new(:plan, options: %w[Free Pro])) }, nil],
    ["Form::Multiselect", -> { bound(Charming::Components::Form::Multiselect.new(:tags, options: %w[a b])) }, nil],
    ["Filepicker", -> { Charming::Components::Filepicker.new(root: @picker_root) }, nil]
  ]

  cases.each do |name, build, mouse_builder|
    it "#{name} returns only Results (or nil) from its handlers" do
      component = instance_exec(&build)
      mouse_event = mouse_builder ? instance_exec(&mouse_builder) : click

      battery = {
        handle_key: %i[up down enter escape tab space].map { |key_name| key(key_name) },
        handle_mouse: [mouse_event],
        handle_paste: [paste]
      }

      battery.each do |handler, events|
        next unless component.respond_to?(handler)

        events.each do |event|
          result = component.public_send(handler, event)
          expect(result).to(be_a(Charming::Components::Result).or(be_nil),
            "#{name}##{handler} returned #{result.inspect} for #{event.inspect}")
        end
      end
    end
  end
end
