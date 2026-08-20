# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Session persistence" do
  def app_class_with(path)
    Class.new(Charming::Application) do
      persist_session to: path
    end
  end

  it "round-trips the session through quit and boot" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tmp", "session.json")
      app_class = app_class_with(path)

      app = app_class.new
      app.session[:count] = 42
      app.session[:name] = "charming"
      app.save_session

      restored = app_class.new
      expect(restored.session[:count]).to eq(42)
      expect(restored.session[:name]).to eq("charming")
    end
  end

  it "never persists framework-internal session keys" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.json")
      app_class = app_class_with(path)

      app = app_class.new
      app.session[:focus_state] = {"SomeController" => {scopes: [{ring: [:content], current: :content, origin: :ring}]}}
      app.session[:command_palette] = {type: :commands, value: "", cursor: 0, selected_index: 0}
      app.session[:theme] = :nord
      app.save_session

      restored = app_class.new
      expect(restored.session).not_to have_key(:focus_state)
      expect(restored.session).not_to have_key(:command_palette)
      expect(restored.session[:theme]).to eq("nord")
    end
  end

  it "skips entries that don't serialize to JSON" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.json")
      app_class = app_class_with(path)

      app = app_class.new
      app.session[:good] = 1
      app.session[:bad] = proc {}
      app.save_session

      restored = app_class.new
      expect(restored.session[:good]).to eq(1)
      expect(restored.session).not_to have_key(:bad)
    end
  end

  it "round-trips component state through quit and boot (deprecated but working)" do
    Charming.instance_variable_set(:@deprecation_emitted, {})
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.json")
      app_class = app_class_with(path)

      app = app_class.new
      controller = Charming::Controller.new(application: app)
      expect do
        controller.component_state(:query, value: "", cursor: 0)[:value] = "charming"
      end.to output(/component_state is deprecated/).to_stderr
      app.save_session

      restored = app_class.new
      restored_controller = Charming::Controller.new(application: restored)
      expect(restored_controller.component_state(:query)[:value]).to eq("charming")
    end
  end

  it "starts with an empty session when the file is corrupt" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.json")
      File.write(path, "{not json")
      app = app_class_with(path).new
      expect(app.session).to eq({})
    end
  end

  it "does not persist when not configured" do
    app = Charming::Application.new
    app.session[:x] = 1
    expect { app.save_session }.not_to raise_error
  end

  it "saves on runtime shutdown" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.json")
      app_class = app_class_with(path)
      controller_class = Class.new(Charming::Controller) do
        key "q", :quit
        def show
          session[:visited] = true
          render "ok"
        end
      end
      stub_const("PersistSpecController", controller_class)
      stub_const("PersistSpecApp", app_class)
      app_class.routes do
        root "persist_spec#show"
      end

      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [Charming::Events::KeyEvent.new(key: :q)]
      )
      Charming::Runtime.new(app_class.new, backend: backend).run

      expect(File).to exist(path)
      expect(JSON.parse(File.read(path))).to include("visited" => true)
    end
  end

  describe "state object persistence" do
    it "round-trips persist-marked attributes and resets unmarked ones to defaults" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "session.json")
        app_class = app_class_with(path)
        state_class = Class.new(Charming::ApplicationState) do
          attribute :count, :integer, default: 0
          attribute :draft, :string, default: ""

          persist :count

          def self.name
            "CounterState"
          end
        end
        stub_const("CounterState", state_class)

        app = app_class.new
        app.session[:states] = {counter: CounterState.new(count: 5, draft: "unsent")}
        app.save_session

        restored = app_class.new
        restored_state = restored.session[:states][:counter]
        expect(restored_state).to be_a(CounterState)
        expect(restored_state.count).to eq(5)
        expect(restored_state.draft).to eq("")
      end
    end

    it "drops undeclared state classes with a one-time warning naming the fix" do
      Charming.instance_variable_set(:@deprecation_emitted, {})
      Dir.mktmpdir do |dir|
        path = File.join(dir, "session.json")
        app_class = app_class_with(path)
        undeclared = Class.new(Charming::ApplicationState) do
          attribute :count, :integer, default: 0

          def self.name
            "UndeclaredState"
          end
        end
        stub_const("UndeclaredState", undeclared)

        app = app_class.new
        app.session[:states] = {counter: UndeclaredState.new(count: 5)}
        expect { app.save_session }.to output(/UndeclaredState.*persist :attr/m).to_stderr
        expect { app.save_session }.not_to output.to_stderr

        restored = app_class.new
        expect(restored.session[:states]).to be_nil
      end
    end

    it "warns once when dropping a non-JSON-safe direct session value" do
      Charming.instance_variable_set(:@deprecation_emitted, {})
      Dir.mktmpdir do |dir|
        path = File.join(dir, "session.json")
        app_class = app_class_with(path)

        app = app_class.new
        app.session[:callback] = proc {}
        expect { app.save_session }.to output(/session\[:callback\]/).to_stderr
        expect { app.save_session }.not_to output.to_stderr
      end
    end

    it "boots with fresh state when the session file references a renamed class or attribute" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "session.json")
        File.write(path, JSON.generate(states: {
          counter: {class: "RenamedAwayState", attributes: {count: 5}},
          other: {class: "StillHereState", attributes: {renamed_attr: 1}}
        }))
        stub_const("StillHereState", Class.new(Charming::ApplicationState) do
          attribute :count, :integer, default: 0

          def self.name
            "StillHereState"
          end
        end)

        log = StringIO.new
        app_class = app_class_with(path)
        app_class.logger(Logger.new(log))
        app = app_class.new

        expect(app.session[:states]).to eq({})
        expect(log.string).to match(/RenamedAwayState.*starting fresh/)
        expect(log.string).to match(/renamed_attr|UnknownAttributeError/)
      end
    end
  end
end
