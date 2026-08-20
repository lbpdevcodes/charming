# frozen_string_literal: true

RSpec.describe Charming::Runtime do
  before do
    stub_const("RuntimeSpecController", controller_class)
    stub_const("RuntimeSpecApp", app_class)
  end

  let(:controller_class) do
    Class.new(Charming::Controller) do
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

  let(:app_class) do
    Class.new(Charming::Application) do
      routes do
        root "runtime_spec#show"
      end
    end
  end

  it "renders the root action and key-dispatched actions" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :up),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.frames).to eq(["Count: 0", "Count: 1"])
  end

  it "keeps raw input active while rendering and reading events" do
    raw_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      attr_reader :raw_events

      def initialize(**)
        super
        @raw_input_active = false
        @raw_events = []
      end

      def with_raw_input
        @raw_events << :entered
        @raw_input_active = true
        yield
      ensure
        @raw_input_active = false
        @raw_events << :left
      end

      def write_frame(frame)
        @raw_events << [:write_frame, @raw_input_active]
        super
      end

      def read_event(timeout: nil)
        @raw_events << [:read_event, @raw_input_active]
        super
      end
    end
    backend = raw_backend.new(events: [Charming::Events::KeyEvent.new(key: :q)])

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.raw_events).to include(:entered, [:write_frame, true], [:read_event, true], :left)
  end

  it "enables and disables mouse tracking around the run loop" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.operations).to include([:enable_mouse_tracking, :drag], :disable_mouse_tracking)
    expect(backend.mouse_enabled?).to be(false)
  end

  it "passes the app's mouse_motion setting to the backend" do
    hover_app = Class.new(Charming::Application) do
      mouse_motion :all
      routes { root "runtime_spec#show" }
    end
    stub_const("HoverRuntimeSpecApp", hover_app)
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(HoverRuntimeSpecApp.new, backend: backend).run

    expect(backend.operations).to include([:enable_mouse_tracking, :all])
  end

  it "passes backend screen dimensions to controllers" do
    screen_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "#{screen.width}x#{screen.height}"
      end
    end
    stub_const("ScreenRuntimeSpecController", screen_controller)
    screen_app = Class.new(Charming::Application) do
      routes do
        root "screen_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)],
      width: 100,
      height: 40
    )

    described_class.new(screen_app.new, backend: backend).run

    expect(backend.frames).to eq(["100x40"])
  end

  it "re-renders the current route after resize events" do
    screen_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "#{screen.width}x#{screen.height}"
      end
    end
    stub_const("ResizeRuntimeSpecController", screen_controller)
    screen_app = Class.new(Charming::Application) do
      routes do
        root "resize_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::ResizeEvent.new(width: 100, height: 40),
        Charming::Events::KeyEvent.new(key: :q)
      ],
      width: 80,
      height: 24
    )

    described_class.new(screen_app.new, backend: backend).run

    expect(backend.frames).to eq(%w[80x24 100x40])
  end

  it "clears and full-repaints after resize instead of overlaying a sparse diff" do
    screen_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "#{screen.width}x#{screen.height}"
      end
    end
    stub_const("ResizeInvalidateRuntimeSpecController", screen_controller)
    screen_app = Class.new(Charming::Application) do
      routes do
        root "resize_invalidate_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::ResizeEvent.new(width: 100, height: 40),
        Charming::Events::KeyEvent.new(key: :q)
      ],
      width: 80,
      height: 24
    )

    described_class.new(screen_app.new, backend: backend).run

    write_ops = backend.operations.select { |op| op.is_a?(Array) && %i[write_frame write_lines].include?(op.first) }
    expect(write_ops).to eq([[:write_frame, "80x24"], [:write_frame, "100x40"]])
    expect(backend.operations.count(:clear)).to eq(3)
  end

  it "navigates to routed screens" do
    home_controller = Class.new(Charming::Controller) do
      key "s", :settings

      def show
        render "Home"
      end

      def settings
        navigate :settings
      end
    end
    settings_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "Settings"
      end
    end
    stub_const("NavigationRuntimeSpecHomeController", home_controller)
    stub_const("NavigationRuntimeSpecSettingsController", settings_controller)
    navigation_app = Class.new(Charming::Application) do
      routes do
        root "navigation_runtime_spec_home#show"
        screen :settings, "navigation_runtime_spec_settings#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :s),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    described_class.new(navigation_app.new, backend: backend).run

    expect(backend.frames).to eq(%w[Home Settings])
  end

  it "passes dynamic route params to navigated controllers" do
    home_controller = Class.new(Charming::Controller) do
      key "u", :user

      def show
        render "Home"
      end

      def user
        navigate :user, id: 123
      end
    end
    user_controller = Class.new(Charming::Controller) do
      key "r", :refresh
      key "q", :quit

      def show
        render "User: #{params[:id]}"
      end

      def refresh
        render "Refresh: #{params[:id]}"
      end
    end
    stub_const("ParamRuntimeSpecHomeController", home_controller)
    stub_const("ParamRuntimeSpecUsersController", user_controller)
    param_app = Class.new(Charming::Application) do
      routes do
        root "param_runtime_spec_home#show"
        screen :user, "param_runtime_spec_users#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :u),
        Charming::Events::KeyEvent.new(key: :r),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    described_class.new(param_app.new, backend: backend).run

    expect(backend.frames).to eq(["Home", "User: 123", "Refresh: 123"])
  end

  it "re-renders the navigated route after resize events" do
    home_controller = Class.new(Charming::Controller) do
      key "s", :settings

      def show
        render "Home"
      end

      def settings
        navigate :settings
      end
    end
    settings_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "Settings: #{screen.width}x#{screen.height}"
      end
    end
    stub_const("ResizeNavigationRuntimeSpecHomeController", home_controller)
    stub_const("ResizeNavigationRuntimeSpecSettingsController", settings_controller)
    navigation_app = Class.new(Charming::Application) do
      routes do
        root "resize_navigation_runtime_spec_home#show"
        screen :settings, "resize_navigation_runtime_spec_settings#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :s),
        Charming::Events::ResizeEvent.new(width: 100, height: 40),
        Charming::Events::KeyEvent.new(key: :q)
      ],
      width: 80,
      height: 24
    )

    described_class.new(navigation_app.new, backend: backend).run

    expect(backend.frames).to eq(["Home", "Settings: 80x24", "Settings: 100x40"])
  end

  it "dispatches due timer events without backend input" do
    timer_controller = Class.new(Charming::Controller) do
      key "q", :quit
      timer :clock, every: 0.1, action: :tick

      def show
        session[:ticks] ||= 0
        render "Ticks: #{session[:ticks]}"
      end

      def tick
        session[:ticks] += 1
        render "Ticks: #{session[:ticks]}"
      end
    end
    stub_const("TimerRuntimeSpecController", timer_controller)
    timer_app = Class.new(Charming::Application) do
      routes do
        root "timer_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :q)]
    )
    times = [0.0, 0.0, 0.0, 0.1, 0.2]
    clock = -> { times.shift || 0.2 }

    described_class.new(timer_app.new, backend: backend, clock: clock).run

    expect(backend.frames).to eq(["Ticks: 0", "Ticks: 1"])
  end

  it "runs an animation timer only between start_timer and stop_timer" do
    anim_controller = Class.new(Charming::Controller) do
      key "s", :begin_slide
      key "q", :quit
      animate :slide, fps: 10, action: :step

      def show
        session[:steps] ||= 0
        render "Steps: #{session[:steps]}"
      end

      def begin_slide
        start_timer(:slide)
        render "Sliding"
      end

      def step
        session[:steps] += 1
        stop_timer(:slide) if session[:steps] >= 2
        render "Steps: #{session[:steps]}"
      end
    end
    stub_const("AnimRuntimeSpecController", anim_controller)
    anim_app = Class.new(Charming::Application) do
      routes do
        root "anim_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        nil,
        Charming::Events::KeyEvent.new(key: :s),
        nil, nil, nil,
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )
    t = 0.0
    clock = -> { t += 0.05 }

    described_class.new(anim_app.new, backend: backend, clock: clock).run

    # No steps before `s` (autostart: false), two steps while running, none after
    # the action stops the timer — even though the clock keeps advancing.
    expect(backend.frames).to eq(["Steps: 0", "Sliding", "Steps: 1", "Steps: 2"])
  end

  it "does not schedule animation timers when navigating to their controller" do
    pulse_controller = Class.new(Charming::Controller) do
      key "q", :quit
      animate :pulse, fps: 10, action: :pulse

      def show
        render "Pulse screen"
      end

      def pulse
        render "Pulsing"
      end
    end
    home_controller = Class.new(Charming::Controller) do
      key "n", :go
      key "q", :quit

      def show
        render "Home"
      end

      def go
        navigate :pulse
      end
    end
    stub_const("PulseRuntimeSpecController", pulse_controller)
    stub_const("HomeRuntimeSpecController", home_controller)
    nav_app = Class.new(Charming::Application) do
      routes do
        root "home_runtime_spec#show"
        screen :pulse, "pulse_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :n),
        nil, nil,
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )
    t = 0.0
    clock = -> { t += 0.05 }

    described_class.new(nav_app.new, backend: backend, clock: clock).run

    expect(backend.frames).to eq(["Home", "Pulse screen"])
  end

  it "does not repaint unchanged timer frames" do
    timer_controller = Class.new(Charming::Controller) do
      key "q", :quit
      timer :clock, every: 0.1, action: :tick

      def show
        render "Still"
      end

      def tick
        render "Still"
      end
    end
    stub_const("UnchangedTimerRuntimeSpecController", timer_controller)
    timer_app = Class.new(Charming::Application) do
      routes do
        root "unchanged_timer_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :q)]
    )
    times = [0.0, 0.0, 0.0, 0.1, 0.2, 0.2, 0.2]
    clock = -> { times.shift || 0.2 }

    described_class.new(timer_app.new, backend: backend, clock: clock).run

    expect(backend.frames).to eq(["Still"])
  end

  it "caps backend reads at the default timeout when timers are later" do
    timer_controller = Class.new(Charming::Controller) do
      key "q", :quit
      timer :clock, every: 10.0, action: :tick

      def show
        render "Waiting"
      end

      def tick
        render "Tick"
      end
    end
    stub_const("ReadTimeoutRuntimeSpecController", timer_controller)
    timer_app = Class.new(Charming::Application) do
      routes do
        root "read_timeout_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)]
    )
    clock = -> { 0.0 }

    described_class.new(timer_app.new, backend: backend, clock: clock).run

    expect(backend.operations).to include([:read_event, described_class::DEFAULT_READ_TIMEOUT])
  end

  it "coalesces a burst of ready task events into a single repaint" do
    task_controller = Class.new(Charming::Controller) do
      key "q", :quit
      on_task :first, action: :landed
      on_task :second, action: :landed
      on_task :third, action: :landed

      def show
        unless session[:started]
          session[:started] = true
          run_task(:first) { 1 }
          run_task(:second) { 2 }
          run_task(:third) { 3 }
        end
        render "Loading"
      end

      def landed
        session[:landed] = session[:landed].to_i + 1
        render "Landed: #{session[:landed]}"
      end
    end
    stub_const("BurstTaskRuntimeSpecController", task_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "burst_task_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(task_app.new, backend: backend, task_executor: Charming::Tasks::InlineExecutor).run

    # All three queued task results dispatch, but only the final state paints.
    expect(backend.frames).to eq(["Loading", "Landed: 3"])
  end

  it "dispatches inline task results before backend input" do
    task_controller = Class.new(Charming::Controller) do
      key "q", :quit
      on_task :fetch, action: :loaded

      def show
        unless session[:started]
          session[:started] = true
          run_task(:fetch) { "feed" }
        end
        render "Loading"
      end

      def loaded
        render "Loaded: #{event.value}"
      end
    end
    stub_const("InlineTaskRuntimeSpecController", task_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "inline_task_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(task_app.new, backend: backend, task_executor: Charming::Tasks::InlineExecutor).run

    expect(backend.frames).to eq(["Loading", "Loaded: feed"])
  end

  it "renders task errors and continues dispatching keys" do
    task_controller = Class.new(Charming::Controller) do
      key "up", :moved
      key "q", :quit
      on_task :fetch, action: :loaded

      def show
        unless session[:started]
          session[:started] = true
          run_task(:fetch) { raise "boom" }
        end
        render "Loading"
      end

      def loaded
        render "Error: #{event.error.message}"
      end

      def moved
        render "Key ok"
      end
    end
    stub_const("ErrorTaskRuntimeSpecController", task_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "error_task_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :up), Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(task_app.new, backend: backend, task_executor: Charming::Tasks::InlineExecutor).run

    expect(backend.frames).to eq(["Loading", "Error: boom", "Key ok"])
  end

  it "drops task events that have no binding after navigation" do
    home_controller = Class.new(Charming::Controller) do
      key "s", :settings
      on_task :fetch, action: :loaded

      def show
        render "Home"
      end

      def settings
        navigate :settings
      end

      def loaded
        render "Loaded"
      end
    end
    settings_controller = Class.new(Charming::Controller) do
      key "q", :quit

      def show
        render "Settings"
      end
    end
    stub_const("StaleTaskRuntimeSpecHomeController", home_controller)
    stub_const("StaleTaskRuntimeSpecSettingsController", settings_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "stale_task_runtime_spec_home#show"
        screen :settings, "stale_task_runtime_spec_settings#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :s),
        Charming::Events::TaskEvent.new(name: :fetch, value: "feed"),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    described_class.new(task_app.new, backend: backend).run

    expect(backend.frames).to eq(%w[Home Settings])
  end

  it "dispatches task events supplied by the backend" do
    task_controller = Class.new(Charming::Controller) do
      key "q", :quit
      on_task :fetch, action: :loaded

      def show
        render "Waiting"
      end

      def loaded
        render "Loaded: #{event.value}"
      end
    end
    stub_const("BackendTaskRuntimeSpecController", task_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "backend_task_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::TaskEvent.new(name: :fetch, value: "feed"), Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(task_app.new, backend: backend).run

    expect(backend.frames).to eq(["Waiting", "Loaded: feed"])
  end

  it "dispatches threaded task results within a few loop iterations" do
    task_controller = Class.new(Charming::Controller) do
      key "q", :quit
      on_task :fetch, action: :loaded

      def show
        unless session[:started]
          session[:started] = true
          run_task(:fetch) { "feed" }
        end
        render "Loading"
      end

      def loaded
        render "Loaded: #{event.value}"
      end
    end
    stub_const("ThreadedTaskRuntimeSpecController", task_controller)
    task_app = Class.new(Charming::Application) do
      routes do
        root "threaded_task_runtime_spec#show"
      end
    end
    yielding_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      def read_event(timeout: nil)
        Thread.pass
        super
      end
    end
    backend = yielding_backend.new(
      events: Array.new(20) + [Charming::Events::KeyEvent.new(key: :q)]
    )

    described_class.new(task_app.new, backend: backend).run

    expect(backend.frames).to include("Loaded: feed")
  end

  it "restores terminal state when a controller raises" do
    failing_controller = Class.new(Charming::Controller) do
      def show
        raise "boom"
      end
    end
    stub_const("FailingRuntimeSpecController", failing_controller)
    failing_app = Class.new(Charming::Application) do
      routes do
        root "failing_runtime_spec#show"
      end
    end
    raw_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      attr_reader :raw_events

      def initialize(**)
        super
        @raw_events = []
      end

      def with_raw_input
        @raw_events << :entered
        yield
      ensure
        @raw_events << :left
      end
    end
    backend = raw_backend.new

    # Controller exceptions no longer crash the runtime — they render an error
    # screen — but terminal state must still be restored when the loop ends.
    described_class.new(failing_app.new, backend: backend).run

    expect(backend.frames.last).to include("RuntimeError")
    expect(backend.frames.last).to include("boom")
    expect(backend.raw_events).to eq(%i[entered left])
    expect(backend.operations).to include(:show_cursor, :leave_alt_screen)
  end

  it "quits on ctrl+c when the controller has no ctrl+c binding" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :c, ctrl: true),
        Charming::Events::KeyEvent.new(key: :up)
      ]
    )

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    # The loop quits at ctrl+c, so the queued :up never increments.
    expect(backend.frames).to eq(["Count: 0"])
  end

  it "lets a controller take over ctrl+c with its own binding" do
    bound_controller = Class.new(Charming::Controller) do
      key "ctrl+c", :copied
      key "q", :quit

      def show
        render "Ready"
      end

      def copied
        render "Copied"
      end
    end
    stub_const("CtrlCRuntimeSpecController", bound_controller)
    bound_app = Class.new(Charming::Application) do
      routes do
        root "ctrl_c_runtime_spec#show"
      end
    end
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :c, ctrl: true),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    described_class.new(bound_app.new, backend: backend).run

    expect(backend.frames).to eq(%w[Ready Copied])
  end

  it "exits the loop when SIGINT arrives as a signal rather than a key" do
    handlers = {}
    allow(Signal).to receive(:trap) do |signal, *args, &block|
      previous = handlers[signal.to_s]
      handlers[signal.to_s] = block || args.first
      previous || "DEFAULT"
    end
    interrupting_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      attr_accessor :on_read

      def read_event(timeout: nil)
        @reads = @reads.to_i + 1
        raise "loop did not exit after interrupt" if @reads > 100

        on_read&.call
        nil
      end

      def exhausted?
        false
      end
    end
    backend = interrupting_backend.new
    backend.on_read = -> { handlers["INT"]&.call } # simulate asynchronous SIGINT delivery

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.operations).to include(:show_cursor, :leave_alt_screen)
  end

  it "quits cleanly on SIGTERM so the terminal is restored" do
    handlers = {}
    allow(Signal).to receive(:trap) do |signal, *args, &block|
      previous = handlers[signal.to_s]
      handlers[signal.to_s] = block || args.first
      previous || "DEFAULT"
    end
    interrupting_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      attr_accessor :on_read

      def read_event(timeout: nil)
        @reads = @reads.to_i + 1
        raise "loop did not exit after SIGTERM" if @reads > 100

        on_read&.call
        nil
      end

      def exhausted?
        false
      end
    end
    backend = interrupting_backend.new
    backend.on_read = -> { handlers["TERM"]&.call }

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.operations).to include(:show_cursor, :leave_alt_screen)
  end

  it "suspends and resumes around SIGTSTP/SIGCONT, repainting on return" do
    handlers = {}
    allow(Signal).to receive(:trap) do |signal, *args, &block|
      previous = handlers[signal.to_s]
      handlers[signal.to_s] = block || args.first
      previous || "DEFAULT"
    end
    allow(Process).to receive(:kill).with("STOP", Process.pid)

    suspendable_backend = Class.new(Charming::Internal::Terminal::MemoryBackend) do
      attr_accessor :on_read

      def suspend
        @operations << :suspend
      end

      def resume
        @operations << :resume
      end

      def notify_resize
        @resize_pending = true
      end

      def read_event(timeout: nil)
        if @resize_pending
          @resize_pending = false
          return Charming::Events::ResizeEvent.new(width: 80, height: 24)
        end
        if on_read
          hook = on_read
          self.on_read = nil
          hook.call
          return nil
        end
        super
      end
    end
    backend = suspendable_backend.new(events: [Charming::Events::KeyEvent.new(key: :q)])
    backend.on_read = -> {
      handlers["TSTP"]&.call
      handlers["CONT"]&.call
    }

    described_class.new(RuntimeSpecApp.new, backend: backend).run

    expect(backend.operations).to include(:suspend, :resume)
    expect(backend.operations.index(:suspend)).to be < backend.operations.index(:resume)
    expect(Process).to have_received(:kill).with("STOP", Process.pid)
    # The resume-triggered resize repaints the screen after returning to the foreground.
    expect(backend.frames).to eq(["Count: 0", "Count: 0"])
  end

  describe "input coalescing (held-key auto-repeat)" do
    let(:counter_controller) do
      Class.new(Charming::Controller) do
        key "up", :increment
        key "down", :decrement
        key "q", :quit

        def show
          session[:count] ||= 0
          render "Count: #{session[:count]}"
        end

        def increment
          session[:count] += 1
          render "Count: #{session[:count]}"
        end

        def decrement
          session[:count] -= 1
          render "Count: #{session[:count]}"
        end
      end
    end

    let(:counter_app) do
      Class.new(Charming::Application) do
        coalesce_input true
        routes { root "coalesce_spec#show" }
      end
    end

    before do
      stub_const("CoalesceSpecController", counter_controller)
      stub_const("CoalesceSpecApp", counter_app)
    end

    it "collapses a burst of identical key events into a single dispatch" do
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :q)
        ]
      )

      described_class.new(CoalesceSpecApp.new, backend: backend).run

      # Initial "Count: 0" then ONE increment — the three :up repeats collapse to one.
      expect(backend.frames).to eq(["Count: 0", "Count: 1"])
    end

    it "does not drop a different key queued behind a repeat burst" do
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :down),
          Charming::Events::KeyEvent.new(key: :q)
        ]
      )

      described_class.new(CoalesceSpecApp.new, backend: backend).run

      # Two :up collapse to one (+1), then the distinct :down still fires (-1).
      expect(backend.frames).to eq(["Count: 0", "Count: 1", "Count: 0"])
    end

    it "dispatches a lone key normally" do
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :q)
        ]
      )

      described_class.new(CoalesceSpecApp.new, backend: backend).run

      expect(backend.frames).to eq(["Count: 0", "Count: 1"])
    end

    it "is off by default: identical repeats each dispatch" do
      stub_const("NoCoalesceApp", Class.new(Charming::Application) do
        routes { root "coalesce_spec#show" }
      end)
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :up),
          Charming::Events::KeyEvent.new(key: :q)
        ]
      )

      described_class.new(NoCoalesceApp.new, backend: backend).run

      expect(backend.frames).to eq(["Count: 0", "Count: 1", "Count: 2"])
    end
  end
end
