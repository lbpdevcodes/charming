# frozen_string_literal: true

require "charming"

module Charming
  # TestHelper provides controller- and component-level test ergonomics for Charming apps,
  # in the spirit of Rails' ActionController::TestCase:
  #
  #   require "charming/test_helper"
  #
  #   RSpec.describe HomeController do
  #     include Charming::TestHelper
  #
  #     let(:ctrl) { build_controller(HomeController) }
  #
  #     it "renders a greeting" do
  #       expect(ctrl.dispatch(:show)).to render_text("Welcome")
  #     end
  #
  #     it "quits on q" do
  #       expect(press(ctrl, "q")).to be_quit
  #     end
  #   end
  #
  # Helpers:
  # - `build_controller(klass, app:, screen:, route:, params:)` — controller instance wired to an app
  # - `key_event("ctrl+p")` — build a KeyEvent from a human-readable string
  # - `press(controller, "down")` — dispatch a key press at the instance, returns the Response
  # - `press_sequence(controller, ["down", "down", "enter"])` — dispatch several presses at one instance
  #
  # RSpec matchers (when RSpec is loaded):
  # - `expect(response).to render_text("...")` / `render_match(/.../)`
  # - `expect(response).to be_quit` / `be_navigate` (predicate matchers on Response)
  # - `expect(response).to navigate_to(:projects)`
  module TestHelper
    # Builds a controller instance with sensible test defaults: a fresh Application and
    # an 80x24 screen. Runs the screen_entered lifecycle hook, mirroring the Runtime's
    # persistent-controller lifecycle.
    def build_controller(controller_class, app: nil, screen: nil, route: nil, params: {})
      app ||= Charming::Application.new
      screen ||= Charming::Screen.new(width: 80, height: 24)
      controller_class.new(application: app, params: params, screen: screen, route: route).tap(&:screen_entered)
    end

    # Builds a KeyEvent from a human-readable string like "q", "down", "ctrl+p",
    # or "shift+tab". Modifier order is irrelevant.
    def key_event(description)
      parts = description.to_s.split("+")
      key = parts.pop
      modifiers = parts.map(&:downcase)
      char = (key.length == 1) ? key : nil
      Charming::Events::KeyEvent.new(
        key: key.to_sym,
        char: char,
        ctrl: modifiers.include?("ctrl") || modifiers.include?("control"),
        alt: modifiers.include?("alt"),
        shift: modifiers.include?("shift")
      )
    end

    # Dispatches a single key press at *controller* (an instance from build_controller)
    # and returns the Response. Accepts a human-readable string or a ready KeyEvent.
    def press(controller, key)
      controller.dispatch_key(key.is_a?(String) ? key_event(key) : key)
    end

    # Dispatches each key in *keys* in order at the same controller instance (mirroring
    # the runtime's persistent-controller model). Returns the last Response.
    def press_sequence(controller, keys)
      keys.map { |key| press(controller, key) }.last
    end

    # Builds a MemoryBackend pre-seeded with KeyEvents parsed from *keys*, ready to be
    # passed to Charming::Runtime for integration-style tests.
    def memory_backend(*keys, width: 80, height: 24)
      events = keys.map { |key| key.is_a?(String) ? key_event(key) : key }
      Charming::Internal::Terminal::MemoryBackend.new(events: events, width: width, height: height)
    end
  end
end

if defined?(RSpec)
  # Both matchers compare against the ANSI-stripped body: styled output interleaves
  # escape codes mid-phrase (each styled segment emits its own codes), so raw
  # substring matching would fail on any text spanning two styles.
  RSpec::Matchers.define :render_text do |expected|
    match do |response|
      response.respond_to?(:body) &&
        Charming::UI::Width.strip_ansi(response.body.to_s).include?(expected)
    end

    failure_message do |response|
      body = response.respond_to?(:body) ? Charming::UI::Width.strip_ansi(response.body.to_s) : response.inspect
      "expected response body to include #{expected.inspect}, got:\n#{body}"
    end
  end

  RSpec::Matchers.define :render_match do |pattern|
    match do |response|
      response.respond_to?(:body) &&
        Charming::UI::Width.strip_ansi(response.body.to_s).match?(pattern)
    end

    failure_message do |response|
      body = response.respond_to?(:body) ? Charming::UI::Width.strip_ansi(response.body.to_s) : response.inspect
      "expected response body to match #{pattern.inspect}, got:\n#{body}"
    end
  end

  RSpec::Matchers.define :navigate_to do |expected_name, **expected_params|
    match do |response|
      next false unless response.respond_to?(:navigate?) && response.navigate?
      next false unless response.name == expected_name.to_sym

      expected_params.empty? || response.params == expected_params
    end

    failure_message do |response|
      "expected a navigation response to #{expected_name.inspect}, got: #{response.inspect}"
    end
  end
end
