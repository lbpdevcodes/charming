# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` contains a more detailed agent guide (API examples, gotchas, code style). Read it for anything not covered here.

## Project

**Charming** is a Rails-inspired terminal UI framework for **Ruby 4+**, packaged as a Bundler gem (`charming.gemspec`). The `charming` executable scaffolds new TUI apps (`charming new`) and generates controllers/screens/components/models inside them.

## Commands

```bash
bundle install           # after checkout or gemspec changes
bin/check                # full check: RSpec + Standard Ruby (default rake task)
bin/ci                   # what CI runs: specs + lint + Zeitwerk eager-load check + gem build
bin/rspec                # tests only (wraps `bundle exec rspec`)
bin/lint                 # Standard Ruby style check
bin/format               # Standard Ruby auto-format
bin/console              # IRB with the gem loaded
bin/run-dummy            # boot spec/dummy app

bundle exec rspec spec/path/to/file_spec.rb            # single file
bundle exec rspec spec/path/to/file_spec.rb:42         # single example by line
```

`script/test` and `script/test_fast` are also available. The Rakefile's default task is `spec + standard`, so `rake` ≡ `bin/check`.

## Architecture

Runtime data flow:

```
Application → Router → Controller → ApplicationState → View → Component → UI
                              Runtime → Renderer → TTY/Memory Backend
```

The framework source under `lib/charming/` is organized as:

- `application.rb`, `router.rb` — Rails-style app + route DSL.
- `controller.rb` — dispatch, `key`/`command`/`timer` bindings, `state(...)`, `render`/`navigate`/`quit`.
- `application_state.rb` — `ActiveModel::Model` + `Attributes`; the only place persistent TUI state lives, stored in `session` and accessed via `Controller#state(name, klass, **attrs)`.
- `runtime.rb` — main event loop. Reads events from the backend, dispatches key/timer/task events to the controller (or open components), passes responses to the renderer.
- `screen.rb`, `response.rb`, `events/` — terminal dimensions, `RenderResponse`/`NavigateResponse`/`QuitResponse`, `KeyEvent`/`ResizeEvent`/`TimerEvent`/`TaskEvent`/`MouseEvent`.
- `presentation/` — view layer: `view.rb`, `component.rb` (inherits `View`), `template_view.rb`, `templates/` (`.tui.erb` rendering), `markdown/`, `components/` (built-in widgets: text_input, list, command_palette, modal, viewport, spinner, …), `ui/` (Lip Gloss–like styling: ANSI, borders, padding, alignment).
- `internal/terminal/` — `tty_backend.rb` (real I/O via tty-cursor/tty-reader/tty-screen) and `memory_backend.rb` (used by almost all specs — no real TTY needed).
- `internal/renderer/` — `full_repaint.rb` and friends.
- `tasks/` — background work: `task.rb`, `inline_executor.rb`, `threaded_executor.rb`. Tasks emit `TaskEvent`s into the runtime loop.
- `focus.rb` — focus traversal across components.
- `generators/` — `charming new` + `charming generate {controller,screen,component,model,view,layout}` scaffolds (`layout` restores the opt-in sidebar/theme/palette chrome).
- `cli.rb`, `database_commands.rb`, `database_installer.rb` — `exe/charming` CLI, including optional SQLite/ActiveRecord install for generated apps.

## Critical invariants

1. **Controllers are persistent per screen.** The Runtime constructs one controller instance when a route is entered and dispatches every event for that screen at it. Ivars hold screen-lifetime state; `state(name, Klass)` objects (in `session`) hold app-lifetime state; `persist_session` covers restart-lifetime. Navigation discards the instance (fresh one on return).
2. **Components inherit `View`.** They share `assigns`, helpers (`text`, `box`, `row`, `column`, `render_component`), and `render`; they don't have an independent lifecycle.
3. **Interactive components signal back via `handle_key` return values**: `:handled`, `[:selected, obj]`, `:cancelled`, or `nil` (not handled).
4. **Command palette key events take priority** over controller `key` bindings while open.
5. **`Charming.run(app)` is the entry point.** Tests pass `backend: MemoryBackend.new(...)` directly to `Runtime` rather than going through `Charming.run`.
6. **`Screen` flows** backend → runtime → controller (`@screen`) → views. Use `@screen.width` / `@screen.height` for layout.
7. **Two `render`s exist**: the view helper returns a styled string; the controller's `render(...)` wraps a string in a `RenderResponse`. Don't conflate them.

## Code style

- Ruby ≥ 4.0, `frozen_string_literal: true` on every file.
- Format with `bin/format`, lint with `bin/lint` (Standard Ruby — don't invoke RuboCop directly).

## Testing

RSpec specs in `spec/` (mirroring `lib/` layout, plus `spec/dummy/` and `spec/examples/`). Prefer `MemoryBackend` for unit specs; reserve `TTYBackend` for integration-level coverage.
