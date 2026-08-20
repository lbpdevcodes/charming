# CHARMING — Agent Guide

## Project

**Charming** is a Rails-inspired terminal user interface (TUI) framework for **Ruby 4+**. It is a **bundler gem** (`charming.gemspec`) providing applications, routing, controller actions, application state, views, components, rendering, generators, and a command palette — with an internal terminal backend layered behind `MemoryBackend` and `TTYBackend`.

---

## Commands

```bash
bundle install          # after checkout or gemspec changes
bin/check               # run everything: RSpec + Standard Ruby
bin/rspec               # tests only
bin/lint                # style checks only
bin/format              # auto-format with Standard Ruby
```

Demo app:
```bash
cd examples/demo_app && bundle install && bundle exec exe/demo_app
```

---

## File Layout

```
lib/charming/             # framework source
  application.rb          # Rails-style Application class (routes, session)
  application_state.rb    # ActiveModel::Model + Attributes
  controller.rb           # dispatch, key/timer bindings, state(session), render/quit/navigate
  router.rb               # route drawing
  runtime.rb              # main event loop (TTY or MemoryBackend)
  screen.rb               # terminal dimensions (width, height)
  spring.rb               # damped-spring physics for animation (harmonica port)
  projectile.rb           # projectile physics + gravity constants (harmonica port)
  response.rb             # RenderResponse / NavigateResponse / QuitResponse
  events.rb               # KeyEvent, ResizeEvent, TimerEvent (Data classes)
  view.rb                 # render helpers: text, box, row, column, style, render_component
  component.rb            # ← inherits View (assigns, helpers)
  ui/                     # Lip Gloss-like styling/layout (ANSI, borders, padding, alignment, dimensions)
  components/             # reusable TUI widgets
    text_input.rb
    list.rb
    command_palette.rb
    modal.rb
    viewport.rb           # scrollable content area
    spinner.rb
  generators/             # `charming new` / `charming generate` scaffold code
  internal/
    timer_control.rb      # runtime surface for start_timer/stop_timer from controllers
    terminal/
      tty_backend.rb      # real TTY I/O (tty-cursor, tty-reader, tty-screen)
      memory_backend.rb   # in-memory I/O for specs & scripts
  renderer/
    full_repaint.rb

spec/                     # RSpec tests (117+ examples)
  examples/               # generated-style demo app tests
  components/             # component specs
  ui/                     # UI subsystem specs
  internal/               # backend/renderer specs
examples/demo_app/        # canonical demo (generated-style, customized)
```

---

## Key Architecture

```
Application → Router → Controller → ApplicationState → View → Component → UI
                              Runtime → Renderer → TTY/Memory Backend
```

- **Runtime** is the main loop: reads events from the backend, dispatches to controller (action keys, timer keys) or components, renders the response.
- One controller instance is created **per route entry** and lives for the screen's lifetime. Ivars hold screen-lifetime state; navigation discards the instance.
- **Application state** objects (in `session` via `Controller#state(name, klass, **attrs)`) hold app-lifetime state that must survive navigation.
- **Components** inherit from `View` to reuse assign readers and helpers (`text`, `box`, `row`, `column`, `render_component`).

### What goes where: the three state lifetimes

1. **Screen-lifetime → controller ivars.** Components with interaction state
   (TextInput, forms, scroll offsets) belong in memoized ivars:
   `@query ||= Components::TextInput.new(...)`. They die with the screen.
   Do not memoize data-bound components (a List of database rows) — rebuild
   them each dispatch or refresh their data, or they serve stale content.
2. **App-lifetime → `state(name, klass, **attrs)` objects.** Domain state that
   must survive navigation. Stored in `session[:states]`; persisted by
   `persist_session` only where JSON-safe.
3. **Restart-lifetime → `persist_session`.** The session hash is serialized as
   JSON on quit and restored on boot. Only JSON-safe values survive.

`session` also holds framework app-global UI state (focus rings, sidebar index,
command palette) and **runtime engine handles** — objects that wrap a live
process or terminal-protocol state, e.g. `session[:audio] ||= Audio::Player.new`
or an `Image::Source` (its `transmitted?` flag gates a one-time transmission).
These are deliberately built once and are **intentionally dropped** by
`save_session`. `component_state` still works (session-backed) but is deprecated:
use ivars for screen-lifetime component state.

---

## Key APIs

### Application

```ruby
class MyApp < Charming::Application
  routes do
    root "home#index"
  end
end
```

### Controller

```ruby
class HomeController < Charming::Controller
  key "up", :increment
  key "down", :decrement
  key "q", :quit

  command "Quit", :quit

  timer :blink, every: 0.5, action: :toggle_spinner

  def show
    render counter.name
  end

  def index
    render_index
  end

  def increment
    counter.value += 1
    show
  end

  private
  def counter
    @counter ||= state(:counter, CounterState)
  end
end
```

### ApplicationState

```ruby
class CounterState < Charming::ApplicationState
  attribute :value, :integer, default: 0
end
```

### Components

Components expose `handle_key(event)` for interactive widgets. Return conventions:

| Return value       | Meaning              |
|--------------------|-----------------------|
| `:handled`        | Key consumed          |
| `[:selected, obj]`| Item selected         |
| `:cancelled`       | Cancelled (e.g. ESC) |
| `nil`              | Not handled           |

Components currently inherit from `View` and use `render` to produce the displayed string.

### Audio playback

`Charming::Audio::Player` plays a sound file by shelling out to a system audio binary
(no new gem dependency). Backends are resolved in priority order: `ffplay` (from ffmpeg)
on any platform, then OS-native players — `afplay` on macOS; `paplay`, `mpg123`, `aplay`
on Linux — raising `Charming::Audio::Player::Unavailable` when none are installed. The
player is **not** a view object: it holds a live child process, so keep it in `session`
(e.g. `session[:audio] ||= Charming::Audio::Player.new`) rather than rebuilding it per
render. For non-blocking playback plus clean teardown on quit, drive it from a `run_task`:

```ruby
run_task(:audio) do
  player.play(sound_path)
  player.wait
ensure
  player.stop   # no-op on normal finish; reaps the child if shutdown interrupts the task
end
```

`Charming::Components::Audio` is the optional one-line status view (`▶`/`■` + label) that
reads `player.playing?`. The `System` adapter (`Charming::Audio::System`) is injectable so
specs never shell out.

---

### Image display

`Charming::Image::Source` displays an image inline using the **Kitty graphics protocol**
with Unicode placeholders (supported terminals so far: **Ghostty** and **Kitty**; others
fall back gracefully). Unlike audio, images go *into* the terminal display, so they can't
just be a string the renderer measures and diffs. Instead the source transmits the image
bytes **once, out of band**, then the view places it by printing ordinary width-1
placeholder cells that ride the normal frame pipeline.

Keep the source in `session` (like the audio player) so its one-time-transmit state
survives re-renders, and render it through `Charming::Components::Image`:

```ruby
def show
  image = session[:logo] ||= Charming::Image::Source.new(path: "logo.png")
  render LogoView.new(image: image, screen: screen, controller: self)
end

# in the view:
render_component(Charming::Components::Image.new(source: image, rows: 8, cols: 16, fallback: "[logo]"))
```

How the pieces fit: `Charming::Image::Terminal` (injectable `env:`) detects the protocol;
`Charming::Image::Protocol::Kitty` builds both the out-of-band transmit (base64-chunked
APC, `q=2`) and the placeholder block (the image id is carried as an **exact** truecolor
foreground — never route it through `UI` styling, whose color downconversion would corrupt
it). The transmit rides the shared out-of-band channel (see below) and the component renders
the `fallback` string on terminals without graphics support.

---

### Out-of-band terminal effects

`Charming::Escape` is the shared channel for escape sequences that must reach the terminal
**before** the next frame, bypassing the line-based renderer (which measures width and would
shred raw control sequences). Anything responding to `#payload` rides it: image transmissions
(`Charming::Image::Transmit`) plus the `Charming::Escape` builders for clipboard (OSC 52),
notifications (OSC 9/777), bell, and window title (OSC 0) — all of which sanitize interpolated
text so it can't break out of the sequence.

Sequences are gathered during a dispatch via a thread-local collector (`Escape.collecting` /
`Escape.register`); the **Runtime** opens the collection around the whole event→response region
(so timer/mouse/paste-driven effects are caught too), attaches the collected list to
`Response#escapes`, and flushes it via `backend.write_escape` ahead of the frame.
`MemoryBackend#escapes` captures it in specs.

Controllers get imperative helpers (`Charming::Controller::Terminal`): `copy(text)`,
`notify(body, title:)`, `bell`, `set_title(text)` — call them in an action alongside a normal
`render`:

```ruby
def copy_url
  copy(state.url)
  notify("Copied!", title: "MyApp")
  render :show
end
```

---

### Data visualization

Pure-text, works on every terminal (no graphics protocol):

- `Charming::UI::BrailleCanvas` — a subpixel drawing surface backed by braille glyphs (U+2800–U+28FF),
  2×4 dots per cell. `new(width_px, height_px)`, `set(x, y)` / `unset` / `line(x0,y0,x1,y1)` (Bresenham),
  `to_s` → braille rows. Composes via `row`/`column`/`Canvas`.
- `Charming::Components::Sparkline` — a series → one-line `▁▂▃▄▅▆▇█` bar graph, one cell per value.
- `Charming::Components::Chart` — `kind: :line` (default) plots a connected line on a `BrailleCanvas`;
  `kind: :bar` draws vertical eighth-block bars. Sized in cells (`width:`/`height:`), optional `style:`.

---

## Code Style (Standard Ruby)

- **Ruby 4.0+** target
- `frozen_string_literal: true` on every file
- Use `bin/format` for auto-formatting
- Use `bin/lint` for style checks
- Follow Standard Ruby formatting rather than invoking RuboCop directly

---

## Testing

RSpec specs live in `spec/`. The `MemoryBackend` is used almost exclusively in specs so no real TTY is needed.

```bash
bundle exec rspec spec/path/to/file_spec.rb   # single file
bundle exec rspec                               # all specs
```

When adding specs for a backend-dependent feature, prefer `MemoryBackend` for unit specs and reserve `TTYBackend` for integration-level tests.

---

## Key Gotchas

1. **Controllers are persistent per screen** — the Runtime constructs one instance per route entry and dispatches all of that screen's events at it. Ivars hold screen-lifetime state; app-lifetime state lives in `ApplicationState` objects via `Controller#state(...)`.
2. **Components inherit View** — they get `assigns`, helper methods, and `render`. They do NOT have their own lifecycle separate from `View`.
3. **`Charming.run(app)` is the entry point** — it instantiates `Runtime` with an optional backend. Tests pass `backend: MemoryBackend.new(...)` directly.
4. **Command palette keys take priority** — an open palette intercepts key events before controller `key_bindings`.
5. **Timers emit `TimerEvent`s** — controllers declare them with `timer :name, every: n, action: :method`; the runtime dispatches through `Controller#dispatch_timer`.
6. **`View#render` returns a string** — the controller wraps it in a `Response.render(...)` which `Runtime` sends to the renderer.
7. **`Screen` dimensions** flow: backend → runtime → controller (as `screen` arg) → view helpers. Use `@screen.width` and `@screen.height` in controllers for layout.
8. **The `render` view helper produces an `UI::Style`-styled string**, and controller `render(...)` wraps that in a response. Don't confuse them.
