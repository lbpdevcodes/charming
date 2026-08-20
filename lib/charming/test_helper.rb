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
  #       expect(press(ctrl_class: HomeController, key: "q")).to be_quit
  #     end
  #   end
  #
  # Helpers:
  # - `build_controller(klass, app:, screen:, route:)` — controller instance wired to an app
  # - `key_event("ctrl+p")` — build a KeyEvent from a human-readable string
  # - `press(controller_or_class, "down")` — dispatch a key press, returns the Response
  # - `press_sequence(klass, ["down", "down", "enter"], app:)` — dispatch several presses
  #
  # RSpec matchers (when RSpec is loaded):
  # - `expect(response).to render_text("...")` / `render_match(/.../)`
  # - `expect(response).to be_quit` / `be_navigate` (predicate matchers on Response)
  # - `expect(response).to navigate_to(:projects)`
  module TestHelper
    # Builds a controller instance with sensible test defaults: a fresh Application,
    # an 80x24 screen, and no event.
    def build_controller(controller_class, app: nil, screen: nil, route: nil, event: nil, params: {})
      app ||= Charming::Application.new
      screen ||= Charming::Screen.new(width: 80, height: 24)
      controller_class.new(application: app, event: event, params: params, screen: screen, route: route)
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

    # Dispatches a single key press against *controller_class* and returns the Response.
    # Pass `app:` to share session state across presses.
    def press(controller_class, key, app:, screen: nil, route: nil)
      controller = build_controller(controller_class, app: app, screen: screen, route: route, event: key_event(key))
      controller.dispatch_key
    end

    # Dispatches each key in *keys* in order against fresh controller instances sharing
    # *app*'s session (mirroring the runtime's controller-per-event model). Returns the
    # last Response.
    def press_sequence(controller_class, keys, app:, screen: nil, route: nil)
      keys.map { |key| press(controller_class, key, app: app, screen: screen, route: route) }.last
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
