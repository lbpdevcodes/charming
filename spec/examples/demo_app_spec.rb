# frozen_string_literal: true

RSpec.describe "demo app example" do
  before(:context) do
    require File.expand_path("../dummy/demo_app/lib/demo_app", __dir__)
  end

  it "renders the generated demo app" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.first).to include("DemoApp")
    expect(backend.frames.first).to include("Status: Idle")
    expect(backend.frames.first).to include("Tab content, then press r for async task.")
  end

  it "registers the LG layout demo route" do
    route = DemoApp::Application.routes.resolve(:lg)

    expect(route.controller_class).to eq(DemoApp::LgController)
    expect(route.action).to eq(:show)
    expect(route.title).to eq("LG Layout")
  end

  it "renders the LG layout demo screen" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)],
      width: 90,
      height: 24
    )
    app = DemoApp::Application.new

    app.routes.resolve(:lg)
    Charming::Runtime.new(app, backend: backend).tap do |runtime|
      runtime.instance_variable_set(:@route, app.routes.resolve(:lg))
      runtime.run
    end

    frame = Charming::UI::Width.strip_ansi(backend.frames.first)
    expect(frame).to include("Working Tree")
    expect(frame).to include("Recent Commits")
    expect(frame).to include("Diff")
    expect(frame).to include("ctrl+p commands")
  end

  it "navigates to the LG layout demo from the command palette" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :l, char: "l"),
        Charming::Events::KeyEvent.new(key: :g, char: "g"),
        Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ],
      width: 90,
      height: 24
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    frames = Charming::UI::Width.strip_ansi(backend.frames.join("\n"))
    expect(frames).to include("LG Layout")
    expect(frames).to include("Working Tree")
    expect(frames).to include("Recent Commits")
  end

  it "tabs through focusable panes on the LG layout demo" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :tab),
        Charming::Events::KeyEvent.new(key: :tab),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ],
      width: 90,
      height: 24
    )
    app = DemoApp::Application.new

    Charming::Runtime.new(app, backend: backend).tap do |runtime|
      runtime.instance_variable_set(:@route, app.routes.resolve(:lg))
      runtime.run
    end

    layout_scope = app.session.dig(:focus_state, "DemoApp::LgController", :scopes).find { |scope| scope[:origin] == :layout }
    expect(layout_scope[:ring]).to eq(%i[status commits files diff])
    expect(layout_scope[:current]).to eq(:files)
  end

  it "renders async loading and completed states" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :tab),
        Charming::Events::KeyEvent.new(key: :r, char: "r"),
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )

    Charming::Runtime.new(
      DemoApp::Application.new,
      backend: backend,
      task_executor: completed_task_executor("Async task finished.")
    ).run

    frames = backend.frames.join("\n")
    expect(frames).to include("Status: Loading")
    expect(frames).to include("Status: Loaded")
    expect(frames).to include("Async task finished.")
  end

  it "does not let idle timers repaint before quit" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [nil, Charming::Events::KeyEvent.new(key: :q)]
    )
    times = [0.0, 0.0, 0.05, 0.05]

    Charming::Runtime.new(
      DemoApp::Application.new,
      backend: backend,
      clock: -> { times.shift || 0.05 }
    ).run

    expect(backend.frames.size).to eq(1)
  end

  it "tabs from sidebar to content before quitting" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :tab), Charming::Events::KeyEvent.new(key: :q, char: "q")],
      width: 60,
      height: 12
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend, clock: -> { 0.0 }).run

    focused_content = Charming::UI::Width.strip_ansi(backend.frames.last)
    expect(focused_content).to include("  ● Home")
    expect(focused_content).not_to include("> ● Home")
  end

  it "clicks content and sidebar panes to move focus" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::MouseEvent.new(button: 0, x: 25, y: 2),
        Charming::Events::MouseEvent.new(button: 0, x: 2, y: 2),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ],
      width: 60,
      height: 12
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend, clock: -> { 0.0 }).run

    content_focused = Charming::UI::Width.strip_ansi(backend.frames[1])
    sidebar_focused = Charming::UI::Width.strip_ansi(backend.frames[2])
    expect(content_focused).to include("  ● Home")
    expect(content_focused).not_to include("> ● Home")
    expect(sidebar_focused).to include("> ● Home")
  end

  it "advances the loading progress while the async task is running" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :tab),
        Charming::Events::KeyEvent.new(key: :r, char: "r"),
        nil,
        Charming::Events::KeyEvent.new(key: :q)
      ]
    )
    times = [0.0, 0.0, 0.05, 0.05, 0.1, 0.1, 0.2, 0.2, 0.3]

    Charming::Runtime.new(
      DemoApp::Application.new,
      backend: backend,
      clock: -> { times.shift || 0.3 },
      task_executor: pending_task_executor
    ).run

    frames = backend.frames.join("\n")
    stripped = Charming::UI::Width.strip_ansi(frames)
    expect(stripped).to include("[=                               ] Working")
    expect(stripped).to include("[==                              ] Working")
    expect(stripped).to include("a!2f$5C+8F%e1~9*B4&Ae%~1=b6Dc#1~ Working.")
  end

  it "does not run the async task when r is pressed while the sidebar is focused" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :r, char: "r"), Charming::Events::KeyEvent.new(key: :q)]
    )

    Charming::Runtime.new(
      DemoApp::Application.new,
      backend: backend,
      task_executor: completed_task_executor("Async task finished.")
    ).run

    frames = backend.frames.join("\n")
    expect(frames).not_to include("Status: Loading")
    expect(frames).not_to include("Status: Loaded")
    expect(frames).not_to include("Async task finished.")
  end

  it "uses backend dimensions when rendering the demo app" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)],
      width: 60,
      height: 12
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.first.lines.count).to eq(12)
  end

  it "renders the command palette modal" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :escape),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.join("\n")).to include("Command palette")
  end

  it "does not open the command palette from a printable p" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, char: "p"),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.join("\n")).not_to include("Command palette")
  end

  it "preserves command palette input between generated demo app dispatches" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :q, char: "q"),
        Charming::Events::KeyEvent.new(key: :escape),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.join("\n")).to include("q|")
    expect(backend.frames.join("\n")).to include("Quit app")
  end

  it "opens the generated demo app theme palette from the command palette" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :t, char: "t"),
        Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
        Charming::Events::KeyEvent.new(key: :escape),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.join("\n")).to include("Search themes")
  end

  it "selects the bundled Phosphor theme from the command palette" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :t, char: "t"),
        Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
        # Several built-in themes ship now — filter the picker down to Phosphor first.
        Charming::Events::KeyEvent.new(key: :p, char: "p"),
        Charming::Events::KeyEvent.new(key: :h, char: "h"),
        Charming::Events::KeyEvent.new(key: :o, char: "o"),
        Charming::Events::KeyEvent.new(key: :s, char: "s"),
        Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.last).to include("\e[1;38;2;255;179;71;48;2;17;26;44m")
  end

  it "switches focus between sidebar and content when Tab cycles focus" do
    initial = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q)]
    )
    after_tab = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :tab), Charming::Events::KeyEvent.new(key: :q)]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: initial).run
    Charming::Runtime.new(DemoApp::Application.new, backend: after_tab).run

    expect(initial.frames.last).to include("> ● Home")
    expect(after_tab.frames.last).to include("  ● Home")
  end

  it "registers the physics demo route" do
    route = DemoApp::Application.routes.resolve(:physics)

    expect(route.controller_class).to eq(DemoApp::PhysicsController)
    expect(route.action).to eq(:show)
    expect(route.title).to eq("Physics")
  end

  it "springs the physics ball to its target and stops the animation timer" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :tab),
        Charming::Events::KeyEvent.new(key: :b, char: "b"),
        *Array.new(200, nil),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ],
      width: 90,
      height: 24
    )
    t = 0.0
    clock = -> { t += 1.0 / 120 }
    app = DemoApp::Application.new

    Charming::Runtime.new(app, backend: backend, clock: clock).tap do |runtime|
      runtime.instance_variable_set(:@route, app.routes.resolve(:physics))
      runtime.run
    end

    frames = backend.frames.map { |frame| Charming::UI::Width.strip_ansi(frame) }
    expect(frames.first).to include("x: 2.0")
    expect(frames.first).to include("spring settled")
    expect(frames).to be_any { |frame| frame.include?("spring running") }
    # The under-damped spring renders many intermediate positions on its way across.
    expect(frames.length).to be > 10
    # Once settled the action stops its own timer; the trailing nil reads with an
    # ever-advancing clock produce no further ticks.
    expect(frames.last).to include("x: 40.0")
    expect(frames.last).to include("spring settled")
  end

  it "selects a command from the palette with enter" do
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [
        Charming::Events::KeyEvent.new(key: :p, ctrl: true),
        Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
        Charming::Events::KeyEvent.new(key: :q, char: "q")
      ]
    )

    Charming::Runtime.new(DemoApp::Application.new, backend: backend).run

    expect(backend.frames.last).to include("DemoApp")
  end

  def completed_task_executor(value)
    lambda do |queue|
      Class.new do
        define_method(:submit) do |name, timeout: nil|
          queue << Charming::Events::TaskEvent.new(name: name, value: value)
          nil
        end

        def shutdown(timeout: 0.0)
        end
      end.new
    end
  end

  def pending_task_executor
    Class.new do
      def submit(name, timeout: nil, &)
        nil
      end

      def shutdown(timeout: 0.0)
      end
    end.new
  end
end
