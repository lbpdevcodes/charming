# Roadmap

## Product Direction

Charming is a Rails-inspired terminal user interface framework for Ruby, aiming for the feature depth and visual polish of the charm.sh stack (bubbletea, lipgloss, bubbles, huh, glamour) with a Rails-flavored public API.

The public API should feel familiar to Rails developers: applications, routes, controllers, views, components, rendering, and conventions. Internally, Charming keeps terminal I/O behind a backend seam so the runtime, tests, components, and application code do not depend directly on TTY gems.

The Ruby floor is `>= 4.0.0` and staying there — Charming is a greenfield framework for current Ruby, not a backport target.

## Architectural Principles

- Prefer Rails-like public concepts over Elm-style public concepts.
- Keep terminal input/output behind internal backend interfaces.
- Keep the in-memory backend as a first-class test backend.
- Keep styling and layout usable independently of the runtime.
- Keep dependencies explicit and ergonomic.
- Make examples and tests part of the deliverable, not afterthoughts.

## Completed

### Foundation

- Conventional Bundler gem structure, RSpec, Standard Ruby, default `rake` task.
- ActiveModel-backed application state (`Charming::ApplicationState`, typed attributes, session-backed controller state).
- Rails-like core: `Application`, `Router` (namespaces, dynamic `/users/:id` params), `Controller`, `Response`, `Runtime`.
- Normalized events: key, resize, mouse, paste, focus, timer, task, task progress.
- Terminal backends (`MemoryBackend`, `TTYBackend`) and renderers (full repaint + line-differential).
- Rails-like views (`View`, helpers, `.tui.erb` templates, layouts, partials), components, themes.
- Background tasks with cancellation, timeouts, and progress streaming; declarative controller timers.
- Generators: `charming new`, controller/screen/view/component/model/migration, optional SQLite/ActiveRecord.
- In-app error screen for controller exceptions, `rescue_from` hooks, session persistence.
- Declarative flex layout engine (splits, grow weights, min/max constraints, focus/scroll/clip/wrap panes).
- Markdown rendering (Commonmarker + Rouge syntax highlighting, tables, task lists, footnotes, definition lists, OSC 8 hyperlinks), Kitty-protocol inline images, audio playback, charts/sparklines via a braille canvas.

### Runtime (bubbletea-class)

- Event loop extracted as a pure event pump (`Internal::EventLoop`): task > timer > input priority, timer-aware read timeouts, opt-in held-key coalescing, burst coalescing of queued task results into a single repaint.
- Correct SGR/legacy mouse decoding: modifier bits (shift/alt/ctrl), motion bit (`drag?`/`motion?`), press-vs-release finals; opt-in buttonless hover via `mouse_motion :all` (1003 tracking).
- Key modifiers: xterm CSI modifier parameters (shift/alt/ctrl arrows, home/end, F1–F12) and ESC-prefixed alt chords, making `ctrl+alt+shift+key` bindings reachable.
- Signal robustness: SIGINT/SIGTERM/SIGHUP exit through terminal restore; SIGTSTP/SIGCONT shell suspend/resume with repaint; idempotent `at_exit` terminal-restore fallback.
- Bracketed paste, focus reporting, SIGWINCH resize, OSC 11 background-color detection at startup.

### Styling (lipgloss-class)

- `UI::Style`: colors (16/256/truecolor with profile detection and downsampling), attributes, padding + margin (shorthand and per-side), width/height, `max_width`/`max_height`, horizontal and vertical alignment, word-wrap and ellipsis-truncate fit modes.
- Adaptive light/dark colors (`UI.adaptive`) resolved against the detected terminal background; markdown `:auto` style.
- Borders: normal/ascii, rounded, thick, double, square, hidden, block; custom `Border` instances; border background and per-side foreground colors.
- Joins and placement with cross-axis alignment (symbolic or fractional 0.0–1.0 positions); compositing overlay canvas.
- Shared ANSI-and-emoji-aware width measurement (`UI::Width`), ANSI-preserving slicing, `UI::Gradient` (blend/steps/per-character colorize), `UI::TextWrapper`, `UI::Truncate`.

### Components (bubbles/huh-class)

- Text input (masking, history, paste), multiline text area, table (windowed, mouse, **column sorting**), list (windowed, mouse, **fuzzy filtering**), multi-select list, tree, viewport, autocomplete, command palette with fzf-style fuzzy matcher.
- Forms à la huh: input/textarea/select/**multiselect**/confirm/note fields, validation, focus traversal, submit semantics.
- Spinner with eleven named presets, gradient progressbar, activity indicator, paginator (dots/arabic), filepicker, timer/stopwatch, modal, help overlay, status bar with key hints, tab bar, toast, badge, breadcrumbs, empty state.
- Stacked focus scopes (ring/layout/modal) with Tab traversal and mouse-click focus.

## Current Milestone

Close the remaining charm.sh feature gaps that need deeper surgery (Next tier below), then shift to the documentation-and-stability push toward 1.0.

## Next

- Kitty keyboard protocol (disambiguated modifiers, key-release events) with graceful fallback.
- Renderer performance: scroll-region optimization and cell-level diffing for list/log-heavy views; render-output caching for static panes.
  (Deferred on measurement, 2026-08: `bin/bench-render` shows the string-frame
  Differential renderer at 0.007 ms/frame median on the 200x60 30fps animate
  workload — far under the 4 ms gate. Revisit only if real apps show render
  hotspots; the benchmark is the decision harness.)
- Styled (non-interactive) table/list/tree builders — lipgloss-style declarative rendering with per-cell style functions.
- Glamour-parity markdown tables: box-drawing borders, `:---`/`---:` column alignment, width capping.
- Form groups (multi-page wizards) and authored per-binding help text for the help overlay.
- Drag lifecycle polish: press/drag/release state machine, double-click detection.
- ANSI-preserving word wrap (styles spanning wrapped lines).
- Runtime alt-screen/inline mode toggle.
- Internal terminal input reader to replace tty-reader (escape-sequence read
  loop, bracketed paste, modifier decoding). tty-cursor/tty-screen were
  replaced by `Internal::Terminal::Cursor`/`Size` in the hardening round;
  tty-reader is the real workhorse, so replacing it is gated on a
  terminal-matrix test plan (Ghostty, kitty, WezTerm, Alacritty, Terminal.app,
  tmux) proving input parity.

## Later

- Accessible mode (huh `WithAccessible`-style screen-reader-friendly prompts).
- Windows terminal support story.
- Release hygiene: CHANGELOG, in-repo getting-started guide and API docs, CI matrix, 1.0 API freeze.
- Harden generated app conventions and app loading.
- Expand examples and documentation.

## Verification

Run the full project check with:

```sh
bin/check
```

Boot the demo app against a real TTY with:

```sh
bin/run-dummy
```

Exercise the flagship example app (SQLite + forms + navigation) with:

```sh
cd examples/journal && bundle exec rspec
```
