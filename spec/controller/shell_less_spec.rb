# frozen_string_literal: true

RSpec.describe "controllers without the app shell" do
  let(:application) { Charming::Application.new }

  # A bare controller: no shell modules included. It must handle keys, mouse,
  # and tab traversal without touching sidebar or command-palette code paths.
  let(:controller_class) do
    Class.new(Charming::Controller) do
      focus_ring :viewer
      key "x", :mark
      key "q", :quit

      slot(:viewer) { Charming::Components::Viewport.new(content: "line", height: 1) }

      def show
        render "shell-less"
      end

      def mark
        render "marked"
      end
    end
  end

  before { stub_const("ShellLessController", controller_class) }

  let(:controller) { controller_class.new(application: application) }

  it "dispatches key bindings" do
    response = controller.dispatch_key(Charming::Events::KeyEvent.new(key: :x, char: "x"))

    expect(response.body).to eq("marked")
  end

  it "cycles the focus ring on tab" do
    controller.dispatch(:show)
    expect { controller.dispatch_key(Charming::Events::KeyEvent.new(key: :tab)) }.not_to raise_error
  end

  it "ignores mouse events" do
    controller.dispatch(:show)
    response = controller.dispatch_mouse(Charming::Events::MouseEvent.new(button: 0, x: 1, y: 1))

    expect(response).to be_nil
  end

  it "quits" do
    response = controller.dispatch_key(Charming::Events::KeyEvent.new(key: :q, char: "q"))

    expect(response.quit?).to be true
  end
end
