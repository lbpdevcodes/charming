# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "charming/cli"

RSpec.describe Charming::CLI do
  it "generates a runnable gem-style app" do
    Dir.mktmpdir do |dir|
      output = StringIO.new

      status = described_class.new(out: output, pwd: dir).call(%w[new weather_tui])

      app_root = File.join(dir, "weather_tui")
      expect(status).to eq(0)
      expect(output.string).to include("create exe/weather_tui")
      expect(output.string).to include("init git")
      expect(File).to exist(File.join(app_root, ".git"))
      expect(File.executable?(File.join(app_root, "exe/weather_tui"))).to be(true)
      expect(File).to exist(File.join(app_root, "weather_tui.gemspec"))
      expect(File.read(File.join(app_root, "weather_tui.gemspec"))).to include(
        'spec.required_ruby_version = ">= 4.0.0"'
      )
      expect(File.read(File.join(app_root, "weather_tui.gemspec"))).to include(
        'spec.metadata["rubygems_mfa_required"] = "true"'
      )
      gemfile = File.read(File.join(app_root, "Gemfile"))
      expect(gemfile).to include('gem "rspec", "~> 3.13"')
      expect(gemfile).to include('gem "rake", "~> 13.0"')
      expect(gemfile).to include('gem "irb"')
      expect(File.read(File.join(app_root, ".rspec"))).to include("--require spec_helper")
      root_file = File.read(File.join(app_root, "lib/weather_tui.rb"))
      expect(root_file).to include("loader = Zeitwerk::Loader.new")
      expect(root_file).to include('loader.inflector.inflect("version" => "VERSION")')
      expect(root_file).to include('loader.push_dir(File.expand_path("../app/state", __dir__), namespace: WeatherTui)')
      expect(root_file).not_to include("Dir[File.expand_path")
      expect(File).to exist(File.join(app_root, "config/routes.rb"))
      expect(File.read(File.join(app_root, "config/routes.rb"))).to include('#   root "home#show"')
      expect(File).not_to exist(File.join(app_root, "config/themes/default.yml"))
      expect(File).not_to exist(File.join(app_root, "config/database.rb"))
      expect(File).not_to exist(File.join(app_root, "app/models"))
      expect(File).to exist(File.join(app_root, "app/state/application_state.rb"))
      expect(File).to exist(File.join(app_root, "app/controllers/application_controller.rb"))
      expect(File).to exist(File.join(app_root, "app/views/layouts/application_layout.rb"))
      expect(File).to exist(File.join(app_root, "spec/spec_helper.rb"))
      expect(File).not_to exist(File.join(app_root, "app/state/home_state.rb"))
      expect(File).not_to exist(File.join(app_root, "app/controllers/home_controller.rb"))
      expect(File).not_to exist(File.join(app_root, "app/views/home"))
      expect(File).not_to exist(File.join(app_root, "spec/state/home_state_spec.rb"))
      expect(File).not_to exist(File.join(app_root, "spec/controllers/home_controller_spec.rb"))
      expect(File).not_to exist(File.join(app_root, "spec/views"))
      expect(File).not_to exist(File.join(app_root, "app/components/command_palette_modal_component.rb"))
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).to include(
        "layout Layouts::ApplicationLayout"
      )
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).not_to include(
        "focus_ring :sidebar, :content"
      )
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).not_to include(
        'key "ctrl+p", :open_command_palette, scope: :global'
      )
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).to include(
        'key "q", :quit, scope: :global'
      )
      expect(File.read(File.join(app_root, "app/views/layouts/application_layout.rb"))).to include(
        "screen_layout"
      )
      expect(File.read(File.join(app_root, "app/views/layouts/application_layout.rb"))).to include(
        "align_vertical(:middle)"
      )
      expect(File.read(File.join(app_root, "app/views/layouts/application_layout.rb"))).not_to include(
        "sidebar"
      )
      expect(File.read(File.join(app_root, "lib/weather_tui/application.rb"))).to include(
        'root File.expand_path("../..", __dir__)'
      )
      expect(File.read(File.join(app_root, "lib/weather_tui/application.rb"))).not_to include(
        "Charming::UI::Theme.built_in_names"
      )
      expect(File.read(File.join(app_root, "lib/weather_tui/application.rb"))).not_to include(
        "default_theme"
      )
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).not_to include(
        'command "Theme", :open_theme_palette'
      )

      require File.join(app_root, "lib/weather_tui")
      expect(WeatherTui::Application.routes.all).to be_empty

      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [Charming::Events::KeyEvent.new(key: :q, char: "q")],
        width: 60,
        height: 12
      )
      Charming::Runtime.new(WeatherTui::Application.new, backend: backend).run
      expect(backend.frames.first).to include("Charming v#{Charming::VERSION}")
      expect(backend.frames.first).to include("A Rails-inspired Ruby TUI framework")
      expect(backend.frames.first).to include("https://github.com/pandorocks/charming")
      expect(backend.frames.first).to include("WeatherTui")
      expect(backend.frames.first).not_to include("> \u{25cf} Home")
      expect(backend.frames.first).not_to include("ctrl+p commands")
      expect(backend.frames.first).not_to include("█")
      expect(backend.frames.first).not_to match(/\e\[\d+;\d+H/)
      expect(backend.frames.first.lines.count).to eq(12)

      skyline_backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [Charming::Events::KeyEvent.new(key: :q, char: "q")],
        width: 80,
        height: 30
      )
      Charming::Runtime.new(WeatherTui::Application.new, backend: skyline_backend).run
      expect(skyline_backend.frames.first).to include("█")
      expect(skyline_backend.frames.first).to include("\e[38;2;240;67;124m")
    end
  end

  it "restores the full app chrome with g layout" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new chrome_tui])
      app_root = File.join(dir, "chrome_tui")

      status = described_class.new(out: output, pwd: app_root).call(%w[g layout])

      expect(status).to eq(0)
      expect(output.string).to include("overwrite app/views/layouts/application_layout.rb")
      expect(output.string).to include("insert chrome app/controllers/application_controller.rb")
      expect(output.string).to include("insert themes lib/chrome_tui/application.rb")

      generated_controller = File.read(File.join(app_root, "app/controllers/application_controller.rb"))
      expect(generated_controller).to include("include Charming::Shell::Sidebar")
      expect(generated_controller).to include("include Charming::Shell::Palette")

      described_class.new(out: output, pwd: app_root).call(%w[g screen dashboard])

      require File.join(app_root, "lib/chrome_tui")
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :p, ctrl: true),
          Charming::Events::KeyEvent.new(key: :escape),
          Charming::Events::KeyEvent.new(key: :q, char: "q")
        ],
        width: 60,
        height: 12
      )
      Charming::Runtime.new(ChromeTui::Application.new, backend: backend).run
      expect(backend.frames.first).to include("ctrl+p commands")
      expect(backend.frames.first).to include("q quit")
      expect(backend.frames.first).to include("> \u{25cf} Dashboard")
      expect(backend.frames.join("\n")).to include("Command palette")

      theme_backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :p, ctrl: true),
          Charming::Events::KeyEvent.new(key: :t, char: "t"),
          Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
          # Several built-in themes ship — filter the picker down to Phosphor.
          Charming::Events::KeyEvent.new(key: :p, char: "p"),
          Charming::Events::KeyEvent.new(key: :h, char: "h"),
          Charming::Events::KeyEvent.new(key: :o, char: "o"),
          Charming::Events::KeyEvent.new(key: :s, char: "s"),
          Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
          Charming::Events::KeyEvent.new(key: :q, char: "q")
        ],
        width: 60,
        height: 12
      )
      Charming::Runtime.new(ChromeTui::Application.new, backend: theme_backend).run
      expect(theme_backend.frames.join("\n")).to include("Search themes")
      expect(theme_backend.frames.last).to include("\e[1;38;2;255;179;71;48;2;17;26;44m")
    end
  end

  it "generates app files in non-namespaced app folders" do
    Dir.mktmpdir do |dir|
      described_class.new(out: StringIO.new, pwd: dir).call(%w[new weather_tui])
      app_root = File.join(dir, "weather_tui")

      output = StringIO.new
      status = described_class.new(out: output, pwd: app_root).call(%w[g controller forecast index])
      described_class.new(out: output, pwd: app_root).call(%w[g view forecast index])
      described_class.new(out: output, pwd: app_root).call(%w[g component forecast_card])

      expect(status).to eq(0)
      expect(output.string).to include("create app/controllers/forecast_controller.rb")
      expect(File).to exist(File.join(app_root, "app/views/forecast/index_view.rb"))
      expect(File).to exist(File.join(app_root, "app/components/forecast_card_component.rb"))
      expect(File.read(File.join(app_root, "app/controllers/forecast_controller.rb"))).to include(
        "class ForecastController < ApplicationController"
      )
      expect(File.read(File.join(app_root, "app/controllers/forecast_controller.rb"))).to include(
        "render :index, palette: command_palette"
      )
      expect(File.read(File.join(app_root, "app/views/forecast/index_view.rb"))).to include(
        '"Forecast"'
      )
    end
  end

  it "generates a sqlite-backed app when requested" do
    Dir.mktmpdir do |dir|
      output = StringIO.new

      status = described_class.new(out: output, pwd: dir).call(%w[new db_tui --database sqlite3])

      app_root = File.join(dir, "db_tui")
      expect(status).to eq(0)
      expect(output.string).to include("create config/database.rb")
      expect(output.string).to include("create app/models/application_record.rb")
      expect(File).to exist(File.join(app_root, "db/migrate/.keep"))
      expect(File).to exist(File.join(app_root, "db/seeds.rb"))
      expect(File.read(File.join(app_root, "db_tui.gemspec"))).to include(
        'spec.add_dependency "activerecord", "~> 8.1"'
      )
      expect(File.read(File.join(app_root, "db_tui.gemspec"))).to include(
        'spec.add_dependency "sqlite3", "~> 2.0"'
      )

      root_file = File.read(File.join(app_root, "lib/db_tui.rb"))
      expect(root_file).to include('require_relative "../config/database"')
      expect(root_file).to include('loader.push_dir(File.expand_path("../app/models", __dir__), namespace: DbTui)')

      require File.join(app_root, "lib/db_tui")

      expect(DbTui::ApplicationRecord.abstract_class?).to be(true)
      expect(ActiveRecord::Base.connection.adapter_name).to eq("SQLite")
    end
  end

  it "installs sqlite support into an existing app" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new install_tui])
      app_root = File.join(dir, "install_tui")

      status = described_class.new(out: output, pwd: app_root).call(%w[db:install sqlite3])

      expect(status).to eq(0)
      expect(output.string).to include("create config/database.rb")
      expect(output.string).to include("create app/models/application_record.rb")
      expect(output.string).to include("update install_tui.gemspec")
      expect(output.string).to include("update lib/install_tui.rb")
      expect(File).to exist(File.join(app_root, "db/migrate/.keep"))
      expect(File).to exist(File.join(app_root, "db/seeds.rb"))

      gemspec = File.read(File.join(app_root, "install_tui.gemspec"))
      expect(gemspec).to include('spec.files = Dir.glob("{app,config,db,exe,lib}/**/*") + %w[README.md]')
      expect(gemspec).to include('spec.add_dependency "activerecord", "~> 8.1"')
      expect(gemspec).to include('spec.add_dependency "sqlite3", "~> 2.0"')

      root_file = File.read(File.join(app_root, "lib/install_tui.rb"))
      expect(root_file).to include('require_relative "../config/database"')
      expect(root_file).to include('loader.push_dir(File.expand_path("../app/models", __dir__), namespace: InstallTui)')

      described_class.new(out: output, pwd: app_root).call(%w[g model note body:text])
      described_class.new(out: output, pwd: app_root).call(%w[db:migrate])
      require File.join(app_root, "lib/install_tui")

      note = InstallTui::Note.create!(body: "Persisted")
      expect(note).to be_persisted
      expect(InstallTui::Note.first.body).to eq("Persisted")
    end
  end

  it "generates an Active Record model and migration for sqlite-backed apps" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new records_tui --database sqlite3])
      app_root = File.join(dir, "records_tui")

      status = described_class.new(out: output, pwd: app_root).call(%w[g model task title:string done:boolean])

      expect(status).to eq(0)
      expect(output.string).to include("create app/models/task.rb")
      expect(output.string).to include("create spec/models/task_spec.rb")

      migration = Dir.glob(File.join(app_root, "db/migrate/*_create_tasks.rb")).first
      expect(migration).not_to be_nil
      expect(File.read(migration)).to include("create_table :tasks")
      expect(File.read(migration)).to include("t.string :title")
      expect(File.read(migration)).to include("t.boolean :done")

      migrate_output = StringIO.new
      migrate_status = described_class.new(out: migrate_output, pwd: app_root).call(%w[db:migrate])
      expect(migrate_status).to eq(0)
      expect(migrate_output.string).to include("migrate db/migrate")

      require File.join(app_root, "lib/records_tui")
      record = RecordsTui::Task.create!(title: "Ship persistence", done: false)

      expect(record).to be_persisted
      expect(RecordsTui::Task.first.title).to eq("Ship persistence")
    end
  end

  it "creates and drops sqlite databases for database-backed apps" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new db_ops_tui --database sqlite3])
      app_root = File.join(dir, "db_ops_tui")
      database_path = File.join(app_root, "db", "development.sqlite3")

      create_output = StringIO.new
      create_status = described_class.new(out: create_output, pwd: app_root).call(%w[db:create])
      expect(create_status).to eq(0)
      expect(create_output.string).to include("create db/development.sqlite3")
      expect(File).to exist(database_path)

      drop_output = StringIO.new
      drop_status = described_class.new(out: drop_output, pwd: app_root).call(%w[db:drop])
      expect(drop_status).to eq(0)
      expect(drop_output.string).to include("drop db/development.sqlite3")
      expect(File).not_to exist(database_path)
    end
  end

  it "rejects model generation without database support" do
    Dir.mktmpdir do |dir|
      described_class.new(out: StringIO.new, pwd: dir).call(%w[new state_tui])
      app_root = File.join(dir, "state_tui")

      error = StringIO.new
      status = described_class.new(out: StringIO.new, err: error, pwd: app_root).call(%w[g model task title:string])

      expect(status).to eq(1)
      expect(error.string).to include("Database support is not configured")
    end
  end

  it "opens the inherited command palette on generated secondary screens" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new nav_tui])
      app_root = File.join(dir, "nav_tui")
      described_class.new(out: output, pwd: app_root).call(%w[g layout])
      described_class.new(out: output, pwd: app_root).call(%w[g controller settings show])
      described_class.new(out: output, pwd: app_root).call(%w[g view settings])
      File.write(
        File.join(app_root, "config/routes.rb"),
        "# frozen_string_literal: true\n\nNavTui::Application.routes do\n  root \"settings#show\"\nend\n"
      )

      require File.join(app_root, "lib/nav_tui")
      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :p, ctrl: true),
          Charming::Events::KeyEvent.new(key: :escape),
          Charming::Events::KeyEvent.new(key: :q, char: "q")
        ]
      )

      Charming::Runtime.new(NavTui::Application.new, backend: backend).run

      expect(backend.frames.join("\n")).to include("Command palette")
      expect(backend.frames.join("\n")).to include("Home")
    end
  end

  it "generates a routed screen reachable from the command palette" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new screen_tui])
      app_root = File.join(dir, "screen_tui")
      described_class.new(out: output, pwd: app_root).call(%w[g layout])

      status = described_class.new(out: output, pwd: app_root).call(%w[g screen settings])

      expect(status).to eq(0)
      expect(output.string).to include("create app/state/settings_state.rb")
      expect(output.string).to include("create app/controllers/settings_controller.rb")
      expect(output.string).to include("create app/views/settings/show_view.rb")
      expect(output.string).to include("insert route config/routes.rb")
      expect(output.string).to include("insert command app/controllers/application_controller.rb")
      expect(File).to exist(File.join(app_root, "spec/state/settings_state_spec.rb"))
      expect(File).to exist(File.join(app_root, "spec/controllers/settings_controller_spec.rb"))
      expect(File).to exist(File.join(app_root, "spec/views/settings/show_view_spec.rb"))
      expect(File.read(File.join(app_root, "spec/state/settings_state_spec.rb"))).to include(
        'describe "#title"'
      )
      expect(File.read(File.join(app_root, "spec/controllers/settings_controller_spec.rb"))).to include(
        'describe "#show"'
      )
      expect(File.read(File.join(app_root, "spec/views/settings/show_view_spec.rb"))).to include(
        'describe "#render"'
      )
      expect(File.read(File.join(app_root, "spec/state/settings_state_spec.rb"))).to include(
        'require "screen_tui"'
      )
      expect(File.read(File.join(app_root, "spec/controllers/settings_controller_spec.rb"))).to include(
        'require "screen_tui"'
      )
      expect(File.read(File.join(app_root, "spec/views/settings/show_view_spec.rb"))).to include(
        'require "screen_tui"'
      )
      expect(File.read(File.join(app_root, "config/routes.rb"))).to include(
        'screen :settings, "settings#show"'
      )
      expect(File.read(File.join(app_root, "app/controllers/application_controller.rb"))).to include(
        'command "Settings" do'
      )

      require File.join(app_root, "lib/screen_tui")
      expect(ScreenTui::Application.routes.resolve(:settings).controller_class).to eq(
        ScreenTui::SettingsController
      )

      backend = Charming::Internal::Terminal::MemoryBackend.new(
        events: [
          Charming::Events::KeyEvent.new(key: :p, ctrl: true),
          Charming::Events::KeyEvent.new(key: :s, char: "s"),
          Charming::Events::KeyEvent.new(key: :e, char: "e"),
          Charming::Events::KeyEvent.new(key: :t, char: "t"),
          Charming::Events::KeyEvent.new(key: :t, char: "t"),
          Charming::Events::KeyEvent.new(key: :i, char: "i"),
          Charming::Events::KeyEvent.new(key: :n, char: "n"),
          Charming::Events::KeyEvent.new(key: :g, char: "g"),
          Charming::Events::KeyEvent.new(key: :s, char: "s"),
          Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
          Charming::Events::KeyEvent.new(key: :p, ctrl: true),
          Charming::Events::KeyEvent.new(key: :enter, char: "\n"),
          Charming::Events::KeyEvent.new(key: :q, char: "q")
        ]
      )

      Charming::Runtime.new(ScreenTui::Application.new, backend: backend).run

      expect(backend.frames.join("\n")).to include("Settings")
      expect(backend.frames.last).to include("ScreenTui")
    end
  end

  it "does not duplicate screen route or command when forced" do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      described_class.new(out: output, pwd: dir).call(%w[new duplicate_tui])
      app_root = File.join(dir, "duplicate_tui")

      described_class.new(out: output, pwd: app_root).call(%w[g screen settings])
      described_class.new(out: output, pwd: app_root).call(%w[g screen settings --force])

      routes = File.read(File.join(app_root, "config/routes.rb"))
      application_controller = File.read(File.join(app_root, "app/controllers/application_controller.rb"))
      expect(routes.scan('screen :settings, "settings#show"').size).to eq(1)
      expect(application_controller.scan('command "Settings" do').size).to eq(1)
    end
  end

  it "rejects the removed g scaffold subcommand" do
    Dir.mktmpdir do |dir|
      described_class.new(out: StringIO.new, pwd: dir).call(%w[new legacy_tui])
      app_root = File.join(dir, "legacy_tui")

      error = StringIO.new
      status = described_class.new(out: StringIO.new, err: error, pwd: app_root).call(%w[g scaffold settings])

      expect(status).to eq(1)
      expect(error.string).to include("Unknown generator: scaffold")
    end
  end

  it "refuses to overwrite existing files" do
    Dir.mktmpdir do |dir|
      described_class.new(out: StringIO.new, pwd: dir).call(%w[new weather_tui])

      error = StringIO.new
      status = described_class.new(err: error, pwd: dir).call(%w[new weather_tui])

      expect(status).to eq(1)
      expect(error.string).to include("File already exists: Gemfile")
    end
  end
end
