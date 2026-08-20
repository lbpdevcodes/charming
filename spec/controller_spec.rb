# frozen_string_literal: true

require "stringio"

RSpec.describe Charming::Controller do
  let(:application) { Charming::Application.new }

  before do
    stub_const("ControllerSpecController", controller_class)
  end

  let(:controller_class) do
    Class.new(described_class) do
      key "up", :increment
      key "q", :quit

      def show
        session[:count] ||= 0
        render "Count: #{session[:count]}"
      end

      def increment
        session[:count] += 1
        render "Count: #{session[:count]}"
      end
    end
  end

  it "renders action responses" do
    response = ControllerSpecController.new(application: application).dispatch(:show)

    expect(response.body).to eq("Count: 0")
  end

  it "delegates logger access to the application" do
    output = StringIO.new
    application.logger = Logger.new(output)
    controller = Class.new(described_class) do
      def show
        logger.info("showing")
        render "Rendered"
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("Rendered")
    expect(output.string).to include("showing")
  end

  it "dispatches key bindings to actions" do
    ControllerSpecController.new(application: application).dispatch(:show)

    response = ControllerSpecController.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :up)
    ).dispatch_key

    expect(response.body).to eq("Count: 1")
  end

  it "does not dispatch printable keys to modifier key bindings" do
    controller = Class.new(described_class) do
      key "ctrl+p", :control

      def control
        render "control"
      end
    end

    printable_response = controller.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :p, char: "p")
    ).dispatch_key
    control_response = controller.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :p, ctrl: true)
    ).dispatch_key

    expect(printable_response).to be_nil
    expect(control_response.body).to eq("control")
  end

  it "accepts control as a ctrl key binding alias" do
    controller = Class.new(described_class) do
      key "control+p", :control

      def control
        render "control"
      end
    end

    response = controller.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :p, ctrl: true)
    ).dispatch_key

    expect(response.body).to eq("control")
  end

  it "auto-renders the configured action when an action produces no response" do
    controller = Class.new(described_class) do
      auto_render :show

      def show
        render "Count: #{session[:count]}"
      end

      def increment
        session[:count] = 1
      end
    end

    response = controller.new(application: application).dispatch(:increment)

    expect(response.body).to eq("Count: 1")
  end

  it "does not auto-render the configured render action into itself" do
    controller = Class.new(described_class) do
      auto_render :show

      def show
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("")
  end

  it "inherits auto-render actions" do
    parent = Class.new(described_class) do
      auto_render :show
    end
    child = Class.new(parent) do
      def show
        render "Rendered"
      end

      def update
      end
    end

    response = child.new(application: application).dispatch(:update)

    expect(response.body).to eq("Rendered")
  end

  it "returns a quit response from controller actions" do
    response = ControllerSpecController.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :q)
    ).dispatch_key

    expect(response).to be_quit
  end

  it "returns a navigation response from controller actions" do
    controller = Class.new(described_class) do
      def settings
        navigate :settings
      end
    end

    response = controller.new(application: application).dispatch(:settings)

    expect(response).to be_navigate
    expect(response.name).to eq(:settings)
  end

  it "renders view objects" do
    view = Class.new(Charming::View) do
      def render
        "Rendered from view"
      end
    end
    controller = Class.new(described_class) do
      define_method(:show) do
        render view.new
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("Rendered from view")
  end

  # Locks in the duck-typed dispatch at controller.rb:50 — `body.render` is
  # invoked, not `body.to_s`. Without distinct return values a refactor to
  # `body.to_s` would silently pass identical-output tests.
  it "invokes #render on a renderable body rather than falling back to #to_s" do
    renderable = Class.new do
      def render = "from-render"
      def to_s = "from-to_s"
    end
    controller = Class.new(described_class) do
      define_method(:show) do
        render renderable.new
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("from-render")
  end

  it "falls back to #to_s when the body does not respond to #render" do
    non_renderable = Object.new
    def non_renderable.to_s = "from-to_s-fallback"
    controller = Class.new(described_class) do
      define_method(:show) { render(non_renderable) }
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("from-to_s-fallback")
  end

  it "wraps rendered bodies with a configured layout" do
    layout = Class.new(Charming::View) do
      def render
        "Layout(#{yield_content})"
      end
    end
    controller = Class.new(described_class) do
      layout layout

      def show
        render "Body"
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("Layout(Body)")
  end

  it "passes view assigns to layouts" do
    view = Class.new(Charming::View) do
      def render
        title
      end
    end
    layout = Class.new(Charming::View) do
      def render
        "#{title}: #{yield_content}"
      end
    end
    controller = Class.new(described_class) do
      layout layout

      define_method(:show) do
        render view.new(title: "Greeting")
      end
    end

    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("Greeting: Greeting")
  end

  it "passes screen and controller to layouts" do
    layout = Class.new(Charming::View) do
      def render
        "#{screen.width}x#{screen.height} #{controller.class.name}: #{yield_content}"
      end
    end
    controller = Class.new(described_class) do
      layout layout

      def show
        render "Body"
      end
    end
    stub_const("LayoutControllerSpecController", controller)

    response = LayoutControllerSpecController.new(
      application: application,
      screen: Charming::Screen.new(width: 100, height: 30)
    ).dispatch(:show)

    expect(response.body).to eq("100x30 LayoutControllerSpecController: Body")
  end

  it "inherits layouts from parent controllers" do
    layout = Class.new(Charming::View) do
      def render
        "Parent(#{yield_content})"
      end
    end
    parent = Class.new(described_class) { layout layout }
    child = Class.new(parent) do
      def show
        render "Body"
      end
    end

    response = child.new(application: application).dispatch(:show)

    expect(response.body).to eq("Parent(Body)")
  end

  it "allows child controllers to override inherited layouts" do
    parent_layout = Class.new(Charming::View) do
      def render
        "Parent(#{yield_content})"
      end
    end
    child_layout = Class.new(Charming::View) do
      def render
        "Child(#{yield_content})"
      end
    end
    parent = Class.new(described_class) { layout parent_layout }
    child = Class.new(parent) do
      layout child_layout

      def show
        render "Body"
      end
    end

    response = child.new(application: application).dispatch(:show)

    expect(response.body).to eq("Child(Body)")
  end

  it "allows child controllers to disable inherited layouts" do
    parent_layout = Class.new(Charming::View) do
      def render
        "Parent(#{yield_content})"
      end
    end
    parent = Class.new(described_class) { layout parent_layout }
    child = Class.new(parent) do
      layout false

      def show
        render "Body"
      end
    end

    response = child.new(application: application).dispatch(:show)

    expect(response.body).to eq("Body")
  end

  it "stores state in application session across controller instances" do
    counter_state = Class.new(Charming::ApplicationState) do
      attribute :count, :integer, default: 0
    end
    controller = Class.new(described_class) do
      define_method(:show) do
        counter = state(:counter, counter_state)
        counter.count += 1
        render "Count: #{counter.count}"
      end
    end

    controller.new(application: application).dispatch(:show)
    response = controller.new(application: application).dispatch(:show)

    expect(response.body).to eq("Count: 2")
  end

  it "stores separate state instances for separate keys" do
    state_class = Class.new(Charming::ApplicationState)
    controller = described_class.new(application: application)

    first = controller.state(:first, state_class)
    second = controller.state(:second, state_class)

    expect(first).not_to equal(second)
  end

  it "persists component state across controller instances" do
    controller = Class.new(described_class) do
      define_method(:show) do
        query = component_state(:query, value: "", cursor: 0)
        input = Charming::Components::TextInput.new(value: query[:value], cursor: query[:cursor])
        input.handle_key(event) if event
        query[:value] = input.value
        query[:cursor] = input.cursor
        render "query: #{query[:value]}"
      end
    end

    controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :a, char: "a")).dispatch(:show)
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :b, char: "b")).dispatch(:show)

    expect(response.body).to eq("query: ab")
  end

  it "seeds component state from defaults on first access only" do
    controller = described_class.new(application: application)

    first = controller.component_state(:filter, value: "initial")
    first[:value] = "changed"

    expect(controller.component_state(:filter, value: "initial")).to eq(value: "changed")
  end

  it "provides default screen dimensions for direct controller use" do
    controller = described_class.new(application: application)

    expect(controller.screen).to eq(Charming::Screen.new(width: 80, height: 24))
  end

  it "dispatches timer bindings to actions" do
    controller = Class.new(described_class) do
      timer :refresh, every: 0.5, action: :refresh

      def refresh
        render "refreshed at #{event.now}"
      end
    end

    response = controller.new(
      application: application,
      event: Charming::Events::TimerEvent.new(name: :refresh, now: 1.5)
    ).dispatch_timer

    expect(response.body).to eq("refreshed at 1.5")
  end

  it "allows timer actions to no-op without rendering a blank response" do
    controller = Class.new(described_class) do
      timer :refresh, every: 0.5, action: :refresh

      def refresh
        nil
      end
    end

    response = controller.new(
      application: application,
      event: Charming::Events::TimerEvent.new(name: :refresh, now: 1.5)
    ).dispatch_timer

    expect(response).to be_nil
  end

  it "runs action hooks around timer actions" do
    controller = Class.new(described_class) do
      timer :refresh, every: 0.5, action: :refresh
      before_action :prepare

      def refresh
        render "prepared: #{@prepared}"
      end

      private

      def prepare
        @prepared = true
      end
    end

    response = controller.new(
      application: application,
      event: Charming::Events::TimerEvent.new(name: :refresh, now: 1.5)
    ).dispatch_timer

    expect(response.body).to eq("prepared: true")
  end

  it "routes timer action errors through rescue_from" do
    controller = Class.new(described_class) do
      timer :refresh, every: 0.5, action: :refresh
      rescue_from RuntimeError, with: :report_error

      def refresh
        raise "boom"
      end

      private

      def report_error(error)
        render "rescued: #{error.message}"
      end
    end

    response = controller.new(
      application: application,
      event: Charming::Events::TimerEvent.new(name: :refresh, now: 1.5)
    ).dispatch_timer

    expect(response.body).to eq("rescued: boom")
  end

  describe "on_task" do
    it "registers task bindings keyed by symbol" do
      controller = Class.new(described_class) do
        on_task "fetch", action: :loaded
      end

      expect(controller.task_bindings).to eq(
        fetch: Charming::Controller::TaskBinding.new(name: :fetch, action: :loaded)
      )
    end

    it "dispatches task bindings to actions" do
      controller = Class.new(described_class) do
        on_task :fetch, action: :loaded

        def loaded
          render "#{event.name}: #{event.value}"
        end
      end

      response = controller.new(
        application: application,
        event: Charming::Events::TaskEvent.new(name: :fetch, value: "feed")
      ).dispatch_task

      expect(response.body).to eq("fetch: feed")
    end

    it "returns nil when no task binding matches" do
      controller = Class.new(described_class)

      response = controller.new(
        application: application,
        event: Charming::Events::TaskEvent.new(name: :missing, value: "feed")
      ).dispatch_task

      expect(response).to be_nil
    end

    it "delegates task submission to the application task executor" do
      executor = Class.new do
        attr_reader :name, :block

        def submit(name, timeout: nil, &block)
          @name = name
          @block = block
          nil
        end
      end.new
      application.task_executor = executor
      controller = Class.new(described_class) do
        def show
          run_task(:fetch) { "feed" }
          render "queued"
        end
      end

      response = controller.new(application: application).dispatch(:show)

      expect(response.body).to eq("queued")
      expect(executor.name).to eq(:fetch)
      expect(executor.block.call).to eq("feed")
    end
  end

  it "opens a command palette from registered commands" do
    controller = Class.new(described_class) do
      command "Quit", :quit

      def show
        render command_palette&.render.to_s
      end
    end

    response = controller.new(application: application).open_command_palette

    expect(response.body).to include("Quit")
  end

  it "stores primitive command palette state in the session" do
    controller = Class.new(described_class) do
      command "Quit", :quit

      def show
        render command_palette&.render.to_s
      end
    end

    controller.new(application: application).open_command_palette

    expect(application.session[:command_palette]).to eq(type: :commands, value: "", cursor: 0, selected_index: 0)
    expect(application.session[:command_palette]).not_to be_a(Charming::Components::CommandPalette)
  end

  it "preserves command palette input across fresh controller instances" do
    controller = Class.new(described_class) do
      command "Open", :show

      def show
        render command_palette&.render.to_s
      end
    end

    controller.new(application: application).open_command_palette
    response = controller.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :o, char: "o")
    ).dispatch_key

    expect(application.session[:command_palette]).to include(value: "o", cursor: 1)
    expect(response.body).to include("o|")
    expect(controller.new(application: application).command_palette.render).to include("o|")
  end

  it "preserves command palette selection across fresh controller instances" do
    controller = Class.new(described_class) do
      command "Open", :show
      command "Run", :show

      def show
        render command_palette&.render.to_s
      end
    end

    controller.new(application: application).open_command_palette
    controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :down)).dispatch_key

    expect(application.session[:command_palette]).to include(selected_index: 1)
    expect(controller.new(application: application).command_palette.selected_command.label).to eq("Run")
  end

  it "replaces command palette state when opening the theme palette from a command" do
    controller = Class.new(described_class) do
      command "Theme", :open_theme_palette

      def show
        render command_palette&.render.to_s
      end
    end

    controller.new(application: application).open_command_palette
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :enter)).dispatch_key

    expect(application.session[:command_palette]).to include(type: :themes, value: "", cursor: 0, selected_index: 0)
    expect(response.body).to include("Search themes")
  end

  it "dispatches keys to an open command palette before normal bindings" do
    controller = Class.new(described_class) do
      key "q", :ignored
      command "Quit", :quit

      def show
        render command_palette&.render.to_s
      end

      def ignored
        render "ignored"
      end
    end

    controller.new(application: application).open_command_palette
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :enter)).dispatch_key

    expect(response).to be_quit
  end

  it "preserves navigation responses from command palette actions" do
    controller = Class.new(described_class) do
      command "Settings", :settings

      def show
        render "Home"
      end

      def settings
        navigate :settings
      end
    end

    controller.new(application: application).open_command_palette
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :enter)).dispatch_key

    expect(response).to be_navigate
    expect(response.name).to eq(:settings)
    expect(application.session).not_to have_key(:command_palette)
  end

  it "executes command blocks in the controller context" do
    controller = Class.new(described_class) do
      command "Settings" do
        navigate :settings
      end

      def show
        render command_palette&.render.to_s
      end
    end

    controller.new(application: application).open_command_palette
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :enter)).dispatch_key

    expect(response).to be_navigate
    expect(response.name).to eq(:settings)
  end

  it "re-renders the default action after palette input" do
    controller = Class.new(described_class) do
      command "Open", :open
      def show = render(command_palette.render)
    end

    controller.new(application: application).open_command_palette
    response = controller.new(
      application: application,
      event: Charming::Events::KeyEvent.new(key: :o, char: "o")
    ).dispatch_key

    expect(response.body).to include("o|")
  end

  it "builds forms with primitive session state" do
    controller = Class.new(described_class) do
      def show
        render signup_form.render
      end

      private

      def signup_form
        form(:signup) do |f|
          f.input :name
        end
      end
    end

    controller.new(application: application).dispatch(:show)

    expect(application.session[:forms][:signup]).to eq(
      values: {name: ""},
      fields: {name: {cursor: 0}},
      errors: {},
      focus_index: 0
    )
    expect(application.session[:forms][:signup]).not_to be_a(Charming::Components::Form)
  end

  it "dispatches submitted form results to focused component hooks" do
    controller = Class.new(described_class) do
      focus_ring :signup_form
      on_submit :signup_form, :signup

      def show
        render signup_form.render
      end

      def signup(values)
        render "submitted #{values[:name]}"
      end

      private

      def signup_form
        form(:signup) do |f|
          f.input :name
        end
      end
    end

    controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :a, char: "a")).dispatch_key
    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :enter)).dispatch_key

    expect(response.body).to eq("submitted a")
  end

  it "dispatches cancelled form results to focused component hooks" do
    controller = Class.new(described_class) do
      focus_ring :signup_form
      on_cancel :signup_form, :cancel_signup

      def show
        render signup_form.render
      end

      def cancel_signup
        render "cancelled"
      end

      private

      def signup_form
        form(:signup) do |f|
          f.input :name
        end
      end
    end

    response = controller.new(application: application, event: Charming::Events::KeyEvent.new(key: :escape)).dispatch_key

    expect(response.body).to eq("cancelled")
  end

  describe ".key_bindings inheritance" do
    it "inherits a copy of parent bindings, not a live reference" do
      parent = Class.new(described_class) { key "up", :foo }
      child = Class.new(parent) { key "down", :bar }

      expect(child.key_bindings).to eq(up: :foo, down: :bar)
      expect(parent.key_bindings).to eq(up: :foo)
      expect(child.key_bindings).not_to equal(parent.key_bindings)
    end

    it "isolates siblings so adding a key to one does not leak to the other" do
      parent = Class.new(described_class) { key "shared", :shared_action }
      sibling1 = Class.new(parent) { key "one", :one_action }
      sibling2 = Class.new(parent) { key "two", :two_action }

      expect(sibling1.key_bindings).to eq(shared: :shared_action, one: :one_action)
      expect(sibling2.key_bindings).to eq(shared: :shared_action, two: :two_action)
    end

    it "cumulates bindings across a three-level chain" do
      grandparent = Class.new(described_class) { key "g", :grand }
      parent = Class.new(grandparent) { key "m", :parent }
      child = Class.new(parent) { key "c", :child }

      expect(child.key_bindings).to eq(g: :grand, m: :parent, c: :child)
    end

    # Snapshot is taken on first read of #key_bindings (which the `key` class
    # macro triggers). Additions to the parent after that point are not visible
    # in the child — locking in this Rails-style inheritance contract.
    it "does not propagate parent additions made after the child has snapshotted" do
      parent = Class.new(described_class) { key "up", :foo }
      child = Class.new(parent) { key "down", :bar }

      parent.key "q", :quit

      expect(parent.key_bindings).to include(q: :quit)
      expect(child.key_bindings).not_to have_key(:q)
    end

    it "stores content scope by default and explicit global scope for key bindings" do
      controller = Class.new(described_class) do
        key "r", :refresh
        key "q", :quit, scope: :global
      end

      expect(controller.key_binding_scopes).to eq(r: :content, q: :global)
    end

    it "inherits key binding scopes as a copy, not a live reference" do
      parent = Class.new(described_class) { key "q", :quit, scope: :global }
      child = Class.new(parent) { key "r", :refresh }

      expect(child.key_binding_scopes).to eq(q: :global, r: :content)
      expect(parent.key_binding_scopes).to eq(q: :global)
      expect(child.key_binding_scopes).not_to equal(parent.key_binding_scopes)
    end

    it "rejects unknown key binding scopes" do
      expect {
        Class.new(described_class) { key "x", :unknown, scope: :sidebar }
      }.to raise_error(ArgumentError, "unknown key scope: :sidebar")
    end
  end

  describe "focus_ring" do
    let(:component_class) do
      Class.new do
        attr_reader :received

        def initialize(echo: true)
          @received = []
          @echo = echo
        end

        def handle_key(event)
          @received << Charming.key_of(event)
          @echo ? :handled : nil
        end
      end
    end

    def focus_controller(component_klass, ring: %i[widget], extra: nil, name: "FocusRingController")
      klass = Class.new(described_class) do
        focus_ring(*ring)

        def show
          render "current=#{focus.current}"
        end

        define_method(:widget) { session[:widget] ||= component_klass.new }
        define_method(:other) { session[:other] ||= component_klass.new(echo: false) }
      end
      klass.instance_exec(&extra) if extra
      stub_const(name, klass)
      klass
    end

    it "auto-dispatches non-bound keys to the focused component" do
      controller_class = focus_controller(component_class)
      controller_class.new(application: application).dispatch(:show)

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :j)
      ).dispatch_key

      expect(application.session[:widget].received).to eq([:j])
    end

    it "drops unbound keys when the focused component returns nil" do
      controller_class = focus_controller(component_class, ring: %i[other])
      controller_class.new(application: application).dispatch(:show)

      response = controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :j)
      ).dispatch_key

      expect(response).to be_nil
      expect(application.session[:other].received).to eq([:j])
    end

    it "drops Tab when no focus_ring is defined" do
      controller_class = Class.new(described_class) { def show = render("ok") }
      stub_const("NoFocusRingController", controller_class)

      response = controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab)
      ).dispatch_key

      expect(response).to be_nil
    end

    it "lets explicit key bindings win over component dispatch" do
      controller_class = focus_controller(
        component_class,
        extra: -> {
          key "q", :quit
        }
      )
      controller_class.new(application: application).dispatch(:show)

      response = controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :q)
      ).dispatch_key

      expect(response).to be_quit
      expect(application.session[:widget]&.received || []).to be_empty
    end

    it "cycles focus on Tab across fresh controller instances" do
      controller_class = focus_controller(component_class, ring: %i[widget other])
      controller_class.new(application: application).dispatch(:show)

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab)
      ).dispatch_key

      expect(controller_class.new(application: application).focus.current).to eq(:other)
    end

    it "cycles focus backward on Shift+Tab" do
      controller_class = focus_controller(component_class, ring: %i[widget other])
      controller_class.new(application: application).dispatch(:show)

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab, shift: true)
      ).dispatch_key

      expect(controller_class.new(application: application).focus.current).to eq(:other)
    end

    it "preserves underlying focus when the command palette opens and closes" do
      controller_class = focus_controller(
        component_class,
        ring: %i[widget other],
        extra: -> { command "Close palette", :close_command_palette }
      )
      controller_class.new(application: application).dispatch(:show)
      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab)
      ).dispatch_key

      controller_class.new(application: application).open_command_palette
      controller_class.new(application: application).close_command_palette

      expect(controller_class.new(application: application).focus.current).to eq(:other)
    end

    it "restores underlying focus after a same-controller command is selected via Enter" do
      controller_class = focus_controller(
        component_class,
        ring: %i[widget other],
        extra: -> {
          command "Render again", :show
        }
      )
      controller_class.new(application: application).dispatch(:show)
      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab)
      ).dispatch_key
      controller_class.new(application: application).open_command_palette

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :enter)
      ).dispatch_key

      reborn = controller_class.new(application: application)
      expect(reborn.focus.current).to eq(:other)
      expect(application.session[:focus_state][controller_class.name][:scopes].length).to eq(1)
    end

    it "restores underlying focus after a navigate-to command is selected via Enter" do
      controller_class = focus_controller(
        component_class,
        extra: -> {
          command "Go somewhere" do
            navigate :other
          end
        }
      )
      controller_class.new(application: application).dispatch(:show)
      controller_class.new(application: application).open_command_palette

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :enter)
      ).dispatch_key

      reborn = controller_class.new(application: application)
      expect(reborn.focus.current).to eq(:widget)
      expect(application.session[:focus_state][controller_class.name][:scopes].length).to eq(1)
    end

    it "delivers subsequent unbound keys to the focused component after a palette command" do
      controller_class = focus_controller(
        component_class,
        extra: -> { command "Render again", :show }
      )
      controller_class.new(application: application).dispatch(:show)
      controller_class.new(application: application).open_command_palette
      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :enter)
      ).dispatch_key

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :j)
      ).dispatch_key

      expect(application.session[:widget].received).to eq([:j])
    end

    it "exposes focused?(:slot) on the controller for views to query" do
      controller_class = focus_controller(component_class, ring: %i[widget other])
      controller = controller_class.new(application: application)
      controller.dispatch(:show)

      expect(controller.focused?(:widget)).to be(true)
      expect(controller.focused?(:other)).to be(false)
    end

    it "uses focus_ring state for sidebar and content focus helpers" do
      controller_class = focus_controller(component_class, ring: %i[sidebar content])

      controller_class.new(application: application).focus_content
      controller = controller_class.new(application: application)

      expect(controller.sidebar_focused?).to be(false)
      expect(controller.content_focused?).to be(true)
    end

    it "moves from sidebar to content on Tab when sidebar is in the focus ring" do
      controller_class = focus_controller(component_class, ring: %i[sidebar content])
      controller_class.new(application: application).dispatch(:show)

      controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :tab)
      ).dispatch_key

      expect(controller_class.new(application: application).focus.current).to eq(:content)
    end

    it "moves focus to the clicked layout pane" do
      view_class = Class.new(Charming::View) do
        def render
          screen_layout do
            split :horizontal do
              pane(:sidebar, width: 10) { "sidebar" }
              pane(:content, grow: 1) { "content" }
            end
          end
        end
      end
      stub_const("MouseFocusView", view_class)
      controller_class = Class.new(described_class) do
        focus_ring :sidebar, :content

        def show
          render_view MouseFocusView
        end
      end
      stub_const("MouseFocusController", controller_class)

      controller_class.new(
        application: application,
        screen: Charming::Screen.new(width: 20, height: 3)
      ).dispatch(:show)
      controller_class.new(
        application: application,
        event: Charming::Events::MouseEvent.new(button: 0, x: 12, y: 1),
        screen: Charming::Screen.new(width: 20, height: 3)
      ).dispatch_mouse

      expect(controller_class.new(application: application).focus.current).to eq(:content)
    end

    it "passes mouse events to clicked components using pane-local coordinates" do
      mouse_component = Class.new do
        attr_reader :received

        def initialize
          @received = []
        end

        def handle_mouse(event)
          received << event
          :handled
        end
      end
      view_class = Class.new(Charming::View) do
        def render
          screen_layout do
            pane(:widget, width: 10, height: 5, border: true, padding: 1) { "widget" }
          end
        end
      end
      stub_const("MouseComponentView", view_class)
      controller_class = Class.new(described_class) do
        focus_ring :widget

        def show
          render_view MouseComponentView
        end

        define_method(:widget) { session[:widget] ||= mouse_component.new }
      end
      stub_const("MouseComponentController", controller_class)

      controller_class.new(
        application: application,
        screen: Charming::Screen.new(width: 10, height: 5)
      ).dispatch(:show)
      controller_class.new(
        application: application,
        event: Charming::Events::MouseEvent.new(button: 0, x: 3, y: 2),
        screen: Charming::Screen.new(width: 10, height: 5)
      ).dispatch_mouse

      received = application.session[:widget].received.first
      expect(received.x).to eq(1)
      expect(received.y).to eq(0)
      expect(received.button_name).to eq(:left)
    end

    it "does not dispatch content-scoped key bindings while the sidebar is focused" do
      controller_class = focus_controller(
        component_class,
        ring: %i[sidebar content],
        extra: -> {
          key "r", :refresh

          def refresh
            session[:refreshed] = true
            render "refreshed"
          end
        }
      )
      controller_class.new(application: application).dispatch(:show)

      response = controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :r)
      ).dispatch_key

      expect(response.body).to eq("current=sidebar")
      expect(application.session[:refreshed]).to be_nil
    end

    it "dispatches global key bindings while the sidebar is focused" do
      controller_class = focus_controller(
        component_class,
        ring: %i[sidebar content],
        extra: -> { key "q", :quit, scope: :global }
      )
      controller_class.new(application: application).dispatch(:show)

      response = controller_class.new(
        application: application,
        event: Charming::Events::KeyEvent.new(key: :q)
      ).dispatch_key

      expect(response).to be_quit
    end

    it "moves focus to content when selecting a sidebar route with a focus ring" do
      controller_class = focus_controller(component_class, ring: %i[sidebar content])
      stub_const("FocusRingSidebarTargetController", controller_class)
      app_class = Class.new(Charming::Application)
      app_class.routes do
        root "focus_ring_sidebar_target#show"
      end
      app = app_class.new

      controller_class.new(application: app).dispatch(:show)
      response = controller_class.new(
        application: app,
        event: Charming::Events::KeyEvent.new(key: :enter)
      ).dispatch_key

      expect(response).to be_navigate
      expect(controller_class.new(application: app).focus.current).to eq(:content)
    end

    it "uses the active route when computing the current sidebar index" do
      controller_class = Class.new(described_class) do
        def show = render("show")
        def settings = render("settings")
      end
      stub_const("RouteAwareSidebarController", controller_class)
      app_class = Class.new(Charming::Application)
      app_class.routes do
        root "route_aware_sidebar#show"
        screen :settings, "route_aware_sidebar#settings"
      end
      route = app_class.routes.resolve(:settings)

      controller = controller_class.new(application: app_class.new, route: route)

      expect(controller.sidebar_index).to eq(1)
      expect(controller.current_route?(route)).to be(true)
    end

    it "allows controllers to override sidebar routes" do
      controller_class = Class.new(described_class) do
        def show = render("show")

        def sidebar_routes
          application.routes.all.last(1)
        end
      end
      stub_const("CustomSidebarRoutesController", controller_class)
      app_class = Class.new(Charming::Application)
      app_class.routes do
        root "custom_sidebar_routes#show"
        screen :other, "custom_sidebar_routes#show"
      end

      controller = controller_class.new(application: app_class.new)

      expect(controller.sidebar_routes.map(&:name)).to eq([:other])
    end

    it "does not track sidebar/content focus when no focus_ring is declared" do
      controller_class = Class.new(described_class) { def show = render("ok") }
      stub_const("NoFocusRingController", controller_class)

      controller_class.new(application: application).focus_content
      controller = controller_class.new(application: application)

      # Without :sidebar/:content in a focus ring, focus calls are no-ops and
      # content keys stay active (content_key_scope_active? defaults to true).
      expect(controller.sidebar_focused?).to be(false)
      expect(controller.content_focused?).to be(false)
      expect(application.session[:focus]).to be_nil
    end
  end

  describe ".focus_ring_slots inheritance" do
    it "inherits a copy of parent slots, not a live reference" do
      parent = Class.new(described_class) { focus_ring :widget }
      child = Class.new(parent) { focus_ring :widget, :other }

      expect(child.focus_ring_slots).to eq(%i[widget other])
      expect(parent.focus_ring_slots).to eq(%i[widget])
      expect(child.focus_ring_slots).not_to equal(parent.focus_ring_slots)
    end

    it "leaves children with the inherited slots when no override is declared" do
      parent = Class.new(described_class) { focus_ring :widget }
      child = Class.new(parent)

      expect(child.focus_ring_slots).to eq(%i[widget])
    end
  end

  describe ".timer_bindings inheritance" do
    it "inherits a copy of parent bindings, not a live reference" do
      parent = Class.new(described_class) { timer :refresh, every: 1, action: :refresh }
      child = Class.new(parent) { timer :poll, every: 2, action: :poll }

      expect(child.timer_bindings.keys).to eq(%i[refresh poll])
      expect(parent.timer_bindings.keys).to eq([:refresh])
      expect(child.timer_bindings).not_to equal(parent.timer_bindings)
    end
  end

  describe ".timer autostart and .animate" do
    it "autostarts declared timers by default" do
      klass = Class.new(described_class) { timer :refresh, every: 1, action: :refresh }

      expect(klass.timer_bindings[:refresh].autostart).to be(true)
    end

    it "stores timers declared with autostart: false" do
      klass = Class.new(described_class) { timer :slide, every: 0.1, action: :step, autostart: false }

      expect(klass.timer_bindings[:slide].autostart).to be(false)
    end

    it "declares an animation as a stopped timer at a frame rate" do
      klass = Class.new(described_class) { animate :slide, fps: 30, action: :step }

      binding = klass.timer_bindings[:slide]
      expect(binding.interval).to eq(1.0 / 30)
      expect(binding.autostart).to be(false)
      expect(binding.action).to eq(:step)
    end

    it "rejects a non-positive fps" do
      expect {
        Class.new(described_class) { animate :slide, fps: 0, action: :step }
      }.to raise_error(ArgumentError, /fps must be positive/)
    end
  end

  describe "timer control helpers" do
    it "delegates start, stop, and running checks to the application's timer control" do
      control = instance_double(Charming::Internal::TimerControl)
      application.timer_control = control
      controller = ControllerSpecController.new(application: application)

      expect(control).to receive(:start).with(:slide)
      expect(control).to receive(:stop).with(:slide)
      expect(control).to receive(:running?).with(:slide).and_return(true)

      controller.start_timer(:slide)
      controller.stop_timer(:slide)
      expect(controller.timer_running?(:slide)).to be(true)
    end

    it "is safe to call outside a runtime" do
      controller = ControllerSpecController.new(application: application)

      expect { controller.start_timer(:slide) }.not_to raise_error
      expect { controller.stop_timer(:slide) }.not_to raise_error
      expect(controller.timer_running?(:slide)).to be(false)
    end
  end

  describe ".task_bindings inheritance" do
    it "inherits a copy of parent bindings, not a live reference" do
      parent = Class.new(described_class) { on_task :fetch, action: :loaded }
      child = Class.new(parent) { on_task :refresh, action: :refreshed }

      expect(child.task_bindings.keys).to eq(%i[fetch refresh])
      expect(parent.task_bindings.keys).to eq([:fetch])
      expect(child.task_bindings).not_to equal(parent.task_bindings)
    end
  end

  describe "dispatch_mouse with sidebar focused" do
    it "does not raise when the sidebar is focused and mouse events arrive" do
      controller_class = Class.new(described_class) do
        focus_ring :sidebar, :content

        def show
        end
      end

      mouse_event = Charming::Events::MouseEvent.new(button: 0, x: 5, y: 2)
      controller = controller_class.new(application: application, event: mouse_event)

      expect(controller.focus.current).to eq(:sidebar)
      result = nil
      expect { result = controller.dispatch_mouse }.not_to raise_error
      expect(result).to be_nil
    end
  end
end
