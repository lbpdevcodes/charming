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
end
