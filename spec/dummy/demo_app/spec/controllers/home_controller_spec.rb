# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe DemoApp::HomeController do
  let(:application) { DemoApp::Application.new }

  subject(:controller) { described_class.new(application: application) }

  describe "#show" do
    it "renders the view with the model" do
      response = controller.dispatch(:show)

      expect(response).to respond_to(:body)
    end
  end

  describe "#refresh" do
    it "renders loading state and queues an async task" do
      executor = Class.new do
        attr_reader :name

        def submit(name, &)
          @name = name
          nil
        end
      end.new
      application.task_executor = executor

      response = controller.dispatch(:refresh)
      body = Charming::UI::Width.strip_ansi(response.body)

      expect(executor.name).to eq(:refresh_home)
      expect(body).to include("Status: Loading")
      expect(body).to include("[=                               ] Working")
      expect(body).to include("f27^_E#cB4A&8F0d$5C+b=3@&AF89*@3 Working.")
    end
  end

  describe "#advance_loading_progress" do
    it "advances the persisted loading progress" do
      application.task_executor = Class.new do
        def submit(name, &)
          nil
        end
      end.new
      controller.dispatch(:refresh)

      response = described_class.new(application: application).dispatch(:advance_loading_progress)
      body = Charming::UI::Width.strip_ansi(response.body)

      expect(body).to include("[==                              ] Working")
      expect(body).to include("f27^_E#cB4A&8F0d$5C+b=3@&AF89*@3 Working.")
    end
  end

  describe "#advance_loading_activity" do
    it "advances the persisted activity indicator" do
      application.task_executor = Class.new do
        def submit(name, &)
          nil
        end
      end.new
      controller.dispatch(:refresh)

      response = described_class.new(application: application).dispatch(:advance_loading_activity)
      body = Charming::UI::Width.strip_ansi(response.body)

      expect(body).to include("[=                               ] Working")
      expect(body).to include("a!2f$5C+8F%e1~9*B4&Ae%~1=b6Dc#1~ Working.")
    end
  end

  describe "#refresh_loaded" do
    it "renders the completed async task result" do
      response = described_class
        .new(application: application)
        .dispatch_task(Charming::Events::TaskEvent.new(name: :refresh_home, value: "Done"))

      expect(response.body).to include("Status: Loaded")
      expect(response.body).to include("Done")
    end
  end
end
