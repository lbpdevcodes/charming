# frozen_string_literal: true

RSpec.describe "Overlay focus scopes capture keys" do
  let(:application) { Charming::Application.new }

  let(:controller_class) do
    Class.new(Charming::Controller) do
      key "n", :go_compose
      key "?", :open_help
      key "q", :quit, scope: :global
      on_cancel :help_overlay, :close_help

      slot(:help_overlay) { Charming::Components::HelpOverlay.new(bindings: {"q" => "Quit"}) }

      def show
        render "help: #{session.fetch(:help_open, false)} composed: #{session.fetch(:composed, false)}"
      end

      def go_compose
        session[:composed] = true
        show
      end

      def open_help
        session[:help_open] = true
        focus.push_scope([:help_overlay], origin: :modal)
        show
      end

      def close_help
        session[:help_open] = false
        focus.pop_scope
        show
      end
    end
  end

  before { stub_const("OverlayScopeSpecController", controller_class) }

  def press(key)
    OverlayScopeSpecController
      .new(application: application)
      .dispatch_key(Charming::Events::KeyEvent.new(key: key))
  end

  it "suppresses content key bindings while a modal scope is open" do
    OverlayScopeSpecController.new(application: application).dispatch(:show)
    press(:"?")

    press(:n) # would navigate without the overlay guard; must close the modal instead

    expect(application.session[:composed]).to be false if application.session.key?(:composed)
    expect(application.session[:help_open]).to be false
  end

  it "routes the dismissing key to the component's cancelled hook" do
    press(:"?")
    expect(application.session[:help_open]).to be true

    press(:enter)
    expect(application.session[:help_open]).to be false
  end

  it "keeps global keys active while the modal is open" do
    press(:"?")
    response = press(:q)
    expect(response.quit?).to be true
  end

  it "behaves normally when no overlay scope is open" do
    response = press(:n)
    expect(application.session[:composed]).to be true
    expect(response.body).to include("composed: true")
  end
end
