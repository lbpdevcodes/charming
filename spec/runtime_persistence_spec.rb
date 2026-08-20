# frozen_string_literal: true

RSpec.describe "persistent controllers" do
  def run_app(app, keys)
    backend = Charming::Internal::Terminal::MemoryBackend.new(events: keys)
    Charming::Runtime.new(app, backend: backend).run
    backend
  end

  def build_app(home:, other: nil)
    stub_const("PersistenceHomeController", home)
    stub_const("PersistenceOtherController", other) if other
    Class.new(Charming::Application) do
      routes do
        root "persistence_home#show"
        screen :other, "persistence_other#show" if other
      end
    end
  end

  it "keeps an ivar counter across key events without session involvement" do
    home = Class.new(Charming::Controller) do
      key "i", :increment
      key "q", :quit

      def show
        render "count: #{@count || 0}"
      end

      def increment
        @count = (@count || 0) + 1
        show
      end
    end
    app = build_app(home: home).new

    backend = run_app(app, [
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])

    expect(backend.frames).to eq(["count: 0", "count: 1", "count: 2", "count: 3"])
    expect(app.session).not_to have_key(:count)
  end

  it "builds a fresh controller when navigating away and back, while state objects survive" do
    stub_const("PersistenceCounterState", Class.new(Charming::ApplicationState) do
      attribute :value, :integer, default: 0
    end)
    home = Class.new(Charming::Controller) do
      key "i", :increment
      key "n", :go_other
      key "q", :quit

      def show
        render "ivar: #{@count || 0} state: #{counter.value}"
      end

      def increment
        @count = (@count || 0) + 1
        counter.value += 1
        show
      end

      def go_other
        navigate :other
      end

      private

      def counter
        state(:counter, PersistenceCounterState)
      end
    end
    other = Class.new(Charming::Controller) do
      key "b", :back

      def show
        render "other"
      end

      def back
        navigate :root
      end
    end
    app = build_app(home: home, other: other).new

    backend = run_app(app, [
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :n, char: "n"),
      Charming::Events::KeyEvent.new(key: :b, char: "b"),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])

    expect(backend.frames).to eq([
      "ivar: 0 state: 0",
      "ivar: 1 state: 1",
      "ivar: 2 state: 2",
      "other",
      "ivar: 0 state: 2"
    ])
  end

  it "fires screen_entered and screen_exited exactly once each around a navigation" do
    lifecycle = []
    home = Class.new(Charming::Controller) do
      key "n", :go_other
      key "q", :quit

      define_method(:screen_entered) { lifecycle << :home_entered }
      define_method(:screen_exited) { lifecycle << :home_exited }

      def show
        render "home"
      end

      def go_other
        navigate :other
      end
    end
    other = Class.new(Charming::Controller) do
      key "b", :back

      define_method(:screen_entered) { lifecycle << :other_entered }
      define_method(:screen_exited) { lifecycle << :other_exited }

      def show
        render "other"
      end

      def back
        navigate :root
      end
    end
    app = build_app(home: home, other: other).new

    run_app(app, [
      Charming::Events::KeyEvent.new(key: :n, char: "n"),
      Charming::Events::KeyEvent.new(key: :b, char: "b"),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])

    expect(lifecycle).to eq(%i[home_entered home_exited other_entered other_exited home_entered home_exited])
  end

  it "updates the screen on the live controller instance after a resize" do
    seen = []
    home = Class.new(Charming::Controller) do
      key "w", :report
      key "q", :quit

      define_method(:screen_entered) { seen << [:entered, self] }

      def show
        render "#{screen.width}x#{screen.height}"
      end

      define_method(:report) do
        seen << [:report, self]
        show
      end
    end
    app = build_app(home: home).new

    backend = run_app(app, [
      Charming::Events::ResizeEvent.new(width: 100, height: 40),
      Charming::Events::KeyEvent.new(key: :w, char: "w"),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])

    expect(backend.frames.last).to eq("100x40")
    expect(seen.map(&:first)).to eq(%i[entered report])
    expect(seen.map(&:last).uniq.length).to eq(1)
  end

  it "does not leak response or event state between dispatches" do
    live_controller = nil
    home = Class.new(Charming::Controller) do
      key "i", :increment
      key "q", :quit

      define_method(:screen_entered) { live_controller = self }

      def show
        render "count: #{@count || 0}"
      end

      def increment
        @count = (@count || 0) + 1
        show
      end
    end
    app = build_app(home: home).new
    backend = Charming::Internal::Terminal::MemoryBackend.new(events: [
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :z, char: "z"), # unbound: produces no response
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])
    Charming::Runtime.new(app, backend: backend).run

    # The unbound key must not re-render the previous dispatch's response.
    expect(backend.frames).to eq(["count: 0", "count: 1"])

    expect(live_controller).not_to be_nil
    expect(live_controller.instance_variable_get(:@response)).to be_nil
    expect(live_controller.event).to be_nil
  end

  it "runs action hooks against the current dispatch's event, not a stale one" do
    seen_keys = []
    home = Class.new(Charming::Controller) do
      key "i", :record
      key "j", :record
      key "q", :quit

      before_action :capture_event, only: :record

      define_method(:capture_event) { seen_keys << event.key }

      def show
        render "home"
      end

      def record
        show
      end
    end
    app = build_app(home: home).new

    run_app(app, [
      Charming::Events::KeyEvent.new(key: :i, char: "i"),
      Charming::Events::KeyEvent.new(key: :j, char: "j"),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])

    expect(seen_keys).to eq(%i[i j])
  end

  it "routes late task events to the current screen's bindings after navigation" do
    received = []
    home = Class.new(Charming::Controller) do
      key "n", :go_other
      on_task :refresh, action: :home_refresh

      define_method(:home_refresh) { received << :home }

      def show
        render "home"
      end

      def go_other
        navigate :other
      end
    end
    other = Class.new(Charming::Controller) do
      key "q", :quit
      on_task :refresh, action: :other_refresh

      define_method(:other_refresh) do
        received << :other
        show
      end

      def show
        render "other"
      end
    end
    app = build_app(home: home, other: other).new

    backend = Charming::Internal::Terminal::MemoryBackend.new(events: [
      Charming::Events::KeyEvent.new(key: :n, char: "n"),
      Charming::Events::TaskEvent.new(name: :refresh, value: nil),
      Charming::Events::KeyEvent.new(key: :q, char: "q")
    ])
    Charming::Runtime.new(app, backend: backend).run

    expect(received).to eq([:other])
  end
end
