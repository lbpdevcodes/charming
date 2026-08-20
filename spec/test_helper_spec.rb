# frozen_string_literal: true

require "charming/test_helper"

RSpec.describe Charming::TestHelper do
  include described_class

  before { stub_const("TestHelperSpecController", controller_class) }

  let(:controller_class) do
    Class.new(Charming::Controller) do
      key "up", :increment
      key "q", :quit
      key "g", :go_settings

      def show
        session[:count] ||= 0
        render "Count: #{session[:count]}"
      end

      def increment
        session[:count] = session.fetch(:count, 0) + 1
        render "Count: #{session[:count]}"
      end

      def go_settings
        navigate :settings
      end
    end
  end

  describe "#build_controller" do
    it "builds a controller with a default app and screen" do
      ctrl = build_controller(TestHelperSpecController)
      expect(ctrl.screen.width).to eq(80)
      expect(ctrl.application).to be_a(Charming::Application)
    end

    it "forwards route params to the controller" do
      ctrl = build_controller(TestHelperSpecController, params: {name: "lbp.dev"})
      expect(ctrl.params).to eq({name: "lbp.dev"})
    end
  end

  describe "#key_event" do
    it "builds a plain key event with char for single characters" do
      event = key_event("q")
      expect(event.key).to eq(:q)
      expect(event.char).to eq("q")
    end

    it "builds named keys without char" do
      event = key_event("down")
      expect(event.key).to eq(:down)
      expect(event.char).to be_nil
    end

    it "parses modifiers in any order" do
      event = key_event("shift+ctrl+p")
      expect(event.key).to eq(:p)
      expect(event.ctrl).to be true
      expect(event.shift).to be true
      expect(event.alt).to be false
    end
  end

  describe "#press and #press_sequence" do
    it "dispatches a key press and returns the response" do
      app = Charming::Application.new
      response = press(TestHelperSpecController, "up", app: app)
      expect(response).to render_text("Count: 1")
    end

    it "shares session state across a sequence" do
      app = Charming::Application.new
      response = press_sequence(TestHelperSpecController, %w[up up up], app: app)
      expect(response).to render_text("Count: 3")
    end
  end

  describe "matchers" do
    let(:app) { Charming::Application.new }

    it "supports render_text" do
      response = build_controller(TestHelperSpecController, app: app).dispatch(:show)
      expect(response).to render_text("Count: 0")
    end

    it "supports render_match" do
      response = build_controller(TestHelperSpecController, app: app).dispatch(:show)
      expect(response).to render_match(/Count: \d+/)
    end

    it "supports be_quit" do
      response = press(TestHelperSpecController, "q", app: app)
      expect(response).to be_quit
    end

    it "supports navigate_to" do
      response = press(TestHelperSpecController, "g", app: app)
      expect(response).to navigate_to(:settings)
    end
  end

  describe "#memory_backend" do
    it "builds a backend pre-seeded with parsed key events" do
      backend = memory_backend("up", "q")
      first = backend.read_event
      expect(first.key).to eq(:up)
      expect(backend.read_event.key).to eq(:q)
    end

    it "drives a full runtime" do
      app_class = Class.new(Charming::Application)
      stub_const("TestHelperSpecApp", app_class)
      app_class.routes do
        root "test_helper_spec#show"
      end

      backend = memory_backend("up", "q")
      Charming::Runtime.new(TestHelperSpecApp.new, backend: backend).run

      expect(backend.frames.last).to include("Count: 1")
    end
  end
end
