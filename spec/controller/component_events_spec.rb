# frozen_string_literal: true

# A focused component whose handle_key always returns the same result.
class StubComponent
  def initialize(result)
    @result = result
  end

  def handle_key(_event)
    @result
  end
end

RSpec.describe "component event dispatch" do
  let(:application) { Charming::Application.new }

  def build_controller(slot:, result:, &class_body)
    slot_name = slot
    stub_component_class = StubComponent
    Class.new(Charming::Controller) do
      focus_ring slot_name

      define_method(:show) { render "base" }
      slot(slot_name) { stub_component_class.new(result) }
      class_eval(&class_body) if class_body
    end
  end

  def press(controller_class, key: :x)
    controller_class.new(application: application).dispatch_key(Charming::Events::KeyEvent.new(key: key, char: key.to_s))
  end

  before do
    Charming.instance_variable_set(:@deprecation_emitted, {})
  end

  after do
    Charming.env = nil
  end

  describe "explicit on_* registrations" do
    it "dispatches a submitted result to the on_submit action with the value" do
      controller = build_controller(slot: :query, result: [:submitted, "ruby"]) do
        on_submit :query, :run_search

        def run_search(value)
          render "searched #{value}"
        end
      end

      expect(press(controller).body).to eq("searched ruby")
    end

    it "dispatches a selected result to the on_select action with the value" do
      controller = build_controller(slot: :results, result: [:selected, 42]) do
        on_select :results, :open_result

        def open_result(value)
          render "opened #{value}"
        end
      end

      expect(press(controller).body).to eq("opened 42")
    end

    it "dispatches a cancelled result to the on_cancel action with no value" do
      controller = build_controller(slot: :query, result: :cancelled) do
        on_cancel :query, :clear_search

        def clear_search
          render "cleared"
        end
      end

      expect(press(controller).body).to eq("cleared")
    end

    it "dispatches Result forms exactly like the legacy forms" do
      controller = build_controller(slot: :query, result: Charming::Components::Result.submitted("ruby")) do
        on_submit :query, :run_search

        def run_search(value)
          render "searched #{value}"
        end
      end

      expect(press(controller).body).to eq("searched ruby")
    end

    it "treats a Result.handled component result like legacy :handled" do
      controller = build_controller(slot: :query, result: Charming::Components::Result.handled)

      expect(press(controller).body).to eq("base")
    end

    it "inherits registrations to subclass controllers" do
      parent = build_controller(slot: :query, result: [:submitted, "ruby"]) do
        on_submit :query, :run_search

        def run_search(value)
          render "parent #{value}"
        end
      end
      child = Class.new(parent)

      expect(press(child).body).to eq("parent ruby")
    end

    it "lets a subclass override a registration without touching the parent" do
      parent = build_controller(slot: :query, result: [:submitted, "ruby"]) do
        on_submit :query, :run_search

        def run_search(value)
          render "parent #{value}"
        end

        def other_search(value)
          render "child #{value}"
        end
      end
      Class.new(parent) { on_submit :query, :other_search }.tap do |child|
        expect(press(child).body).to eq("child ruby")
        expect(press(parent).body).to eq("parent ruby")
      end
    end
  end

  describe "legacy <slot>_<event> fallback" do
    it "dispatches to the convention method with a one-time deprecation warning" do
      stub_const("LegacySearchController", build_controller(slot: :query, result: [:submitted, "ruby"]) do
        def query_submitted(value)
          render "legacy #{value}"
        end
      end)

      expect { expect(press(LegacySearchController).body).to eq("legacy ruby") }
        .to output(/query_submitted.*on_submit :query, :query_submitted/m).to_stderr
    end

    it "warns only once per controller, slot, and event" do
      stub_const("LegacySearchController", build_controller(slot: :query, result: [:submitted, "ruby"]) do
        def query_submitted(value)
          render "legacy #{value}"
        end
      end)

      expect do
        press(LegacySearchController)
        press(LegacySearchController)
      end.to output(/query_submitted/).to_stderr.and(
        output(/\A(?:.*\n){0,2}\z/).to_stderr
      )
    end
  end

  describe "strict miss" do
    it "raises UnhandledComponentEvent naming the slot, event, and declaration" do
      controller = build_controller(slot: :query, result: [:submitted, "ruby"]) do
        def querys_submitted(_value) # the typo: plural slot name
          render "typo"
        end
      end

      expect { press(controller) }
        .to raise_error(Charming::UnhandledComponentEvent, /:query :submitted.*on_submit :query/m)
    end

    it "falls back to the default render with a logged warning in production" do
      Charming.env = "production"
      log = StringIO.new
      application.logger = Logger.new(log)
      controller = build_controller(slot: :query, result: [:submitted, "ruby"])

      expect(press(controller).body).to eq("base")
      expect(log.string).to match(/:query :submitted.*on_submit :query/m)
    end
  end
end
