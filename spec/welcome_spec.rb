# frozen_string_literal: true

RSpec.describe Charming::Welcome do
  def run_app(app_class, width: 80, height: 30)
    backend = Charming::Internal::Terminal::MemoryBackend.new(
      events: [Charming::Events::KeyEvent.new(key: :q, char: "q")],
      width: width,
      height: height
    )
    Charming::Runtime.new(app_class.new, backend: backend).run
    backend
  end

  it "shows the built-in welcome screen when the app has no routes" do
    stub_const("WelcomeSpec::Application", Class.new(Charming::Application))

    backend = run_app(WelcomeSpec::Application)

    frame = backend.frames.first
    expect(frame).to include("WelcomeSpec")
    expect(frame).to include("A Rails-inspired Ruby TUI framework")
    expect(frame).to include("Charming v#{Charming::VERSION}")
    expect(frame).to include("https://github.com/lbpdevcodes/charming")
    expect(frame).to include("config/routes.rb")
    expect(frame).to include("\e[38;2;240;67;124m")
  end

  it "hides the skyline art on screens too small for it" do
    stub_const("WelcomeSpec::Application", Class.new(Charming::Application))

    backend = run_app(WelcomeSpec::Application, width: 60, height: 12)

    expect(backend.frames.first).not_to include("█")
    expect(backend.frames.first).to include("Charming v#{Charming::VERSION}")
  end

  it "boots the first registered route when the app has routes but no root" do
    stub_const("SettingsController", Class.new(Charming::Controller) do
      key "q", :quit, scope: :global

      def show
        render "Settings screen"
      end
    end)
    stub_const("WelcomeSpec::Application", Class.new(Charming::Application) do
      routes do
        screen :settings, "settings#show"
      end
    end)

    backend = run_app(WelcomeSpec::Application)

    expect(backend.frames.first).to include("Settings screen")
    expect(backend.frames.first).not_to include("https://github.com/lbpdevcodes/charming")
  end
end
