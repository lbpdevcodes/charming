# frozen_string_literal: true

RSpec.describe "declared slots" do
  let(:application) { Charming::Application.new }

  it "resolves a declared slot through component_for" do
    controller_class = Class.new(Charming::Controller) do
      slot :query do
        Charming::Components::TextInput.new(value: "ruby")
      end
    end

    component = controller_class.new(application: application).component_for(:query)

    expect(component).to be_a(Charming::Components::TextInput)
    expect(component.value).to eq("ruby")
  end

  it "memoizes a declared slot for the controller's lifetime and resets on a fresh controller" do
    controller_class = Class.new(Charming::Controller) do
      slot(:results) { Charming::Components::List.new(items: []) }
    end

    controller = controller_class.new(application: application)
    expect(controller.component_for(:results)).to equal(controller.component_for(:results))
    fresh = controller_class.new(application: application)
    expect(fresh.component_for(:results)).not_to equal(controller.component_for(:results))
  end

  it "instance_execs the factory against the controller, so it can read params" do
    controller_class = Class.new(Charming::Controller) do
      slot(:greeting) { Charming::Components::TextInput.new(value: params[:name]) }
    end

    component = controller_class.new(application: application, params: {name: "ruby"}).component_for(:greeting)

    expect(component.value).to eq("ruby")
  end

  it "defines a private reader returning the memoized component" do
    controller_class = Class.new(Charming::Controller) do
      slot(:results) { Charming::Components::List.new(items: %w[a b]) }

      def show
        render "count: #{results.items.length}"
      end
    end

    controller = controller_class.new(application: application)
    expect(controller).not_to respond_to(:results)
    expect(controller.dispatch(:show).body).to eq("count: 2")
    expect(controller.send(:results)).to equal(controller.component_for(:results))
  end

  it "resolves undeclared slots via the method convention with a one-time deprecation" do
    controller_class = Class.new(Charming::Controller) do
      def self.name
        "LegacySlotsController"
      end

      private

      def query
        @query ||= Charming::Components::TextInput.new(value: "legacy")
      end
    end
    controller = controller_class.new(application: application)

    expect { @resolved = controller.component_for(:query) }.to output(/slot :query/).to_stderr
    expect(@resolved.value).to eq("legacy")
    expect { controller.component_for(:query) }.not_to output.to_stderr
  end

  it "returns nil for a slot nothing declares, without warning" do
    controller_class = Class.new(Charming::Controller)
    controller = controller_class.new(application: application)

    expect { @missing = controller.component_for(:nothing) }.not_to output.to_stderr
    expect(@missing).to be_nil
  end

  it "defaults the focus ring to declared slots in declaration order, filtered to components" do
    controller_class = Class.new(Charming::Controller) do
      slot(:query) { Charming::Components::TextInput.new }
      slot(:plain) { "not a component" }
      slot(:results) { Charming::Components::List.new(items: []) }
    end

    expect(controller_class.new(application: application).focus.ring).to eq([:query, :results])
  end

  it "lets an explicit focus_ring win over declared slots" do
    controller_class = Class.new(Charming::Controller) do
      focus_ring :results

      slot(:query) { Charming::Components::TextInput.new }
      slot(:results) { Charming::Components::List.new(items: []) }
    end

    expect(controller_class.new(application: application).focus.ring).to eq([:results])
  end

  it "inherits slot definitions and lets a subclass override them" do
    parent = Class.new(Charming::Controller) do
      slot(:query) { Charming::Components::TextInput.new(value: "parent") }
      slot(:results) { Charming::Components::List.new(items: []) }
    end
    child = Class.new(parent) do
      slot(:query) { Charming::Components::TextInput.new(value: "child") }
    end

    controller = child.new(application: application)
    expect(controller.component_for(:query).value).to eq("child")
    expect(controller.component_for(:results)).to be_a(Charming::Components::List)
    expect(controller.focus.ring).to eq([:query, :results])
  end

  describe "layout slot validation" do
    def build_layout_controller(pane_names)
      Class.new(Charming::Controller) do
        slot(:query) { Charming::Components::TextInput.new }

        define_method(:show) do
          view = Class.new(Charming::View) do
            define_method(:render) do
              screen_layout do
                split(:horizontal) do
                  pane_names.each { |name| pane(name, focus: true) { "x" } }
                end
              end
            end
          end
          render view.new(screen: screen, controller: self)
        end
      end
    end

    it "raises UnknownSlot for a focusable pane that nothing declares, listing declared slots" do
      controller_class = build_layout_controller([:query, :mystery])

      expect { controller_class.new(application: application).dispatch(:show) }
        .to raise_error(Charming::UnknownSlot, /:mystery.*:query/m)
    end

    it "accepts panes declared as slots" do
      controller_class = build_layout_controller([:query])

      expect { controller_class.new(application: application).dispatch(:show) }.not_to raise_error
    end

    it "logs instead of raising in production" do
      Charming.env = "production"
      log = StringIO.new
      application.logger = Logger.new(log)
      controller_class = build_layout_controller([:mystery])

      controller_class.new(application: application).dispatch(:show)

      expect(log.string).to match(/:mystery/)
    ensure
      Charming.env = nil
    end
  end

  describe "on_* registration validation" do
    it "raises UnknownSlot at first dispatch for a registration nothing declares" do
      controller_class = Class.new(Charming::Controller) do
        on_submit :ghost, :handle_ghost

        def handle_ghost(*)
        end

        def show
          render "ok"
        end
      end

      expect { controller_class.new(application: application).dispatch(:show) }
        .to raise_error(Charming::UnknownSlot, /:ghost.*slot/m)
    end

    it "accepts registrations for slots declared later in the class body" do
      controller_class = Class.new(Charming::Controller) do
        on_submit :query, :run_search

        slot(:query) { Charming::Components::TextInput.new }

        def run_search(value)
          render value
        end

        def show
          render "ok"
        end
      end

      expect { controller_class.new(application: application).dispatch(:show) }.not_to raise_error
    end

    it "logs instead of raising in production" do
      Charming.env = "production"
      log = StringIO.new
      application.logger = Logger.new(log)
      controller_class = Class.new(Charming::Controller) do
        on_select :ghost, :handle_ghost

        def handle_ghost(*)
        end

        def show
          render "ok"
        end
      end

      response = controller_class.new(application: application).dispatch(:show)

      expect(response.body).to eq("ok")
      expect(log.string).to match(/:ghost/)
    ensure
      Charming.env = nil
    end
  end
end
