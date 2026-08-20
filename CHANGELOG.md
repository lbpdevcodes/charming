# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ApplicationState.persist :attr, ...`: explicit attribute persistence for
  `persist_session`. State objects serialize as their class name plus the
  marked (JSON-safe) attributes and re-instantiate on boot; unmarked
  attributes reset to defaults. A session file referencing a renamed class or
  attribute logs a warning and starts that state fresh — boot never crashes.
- `Charming::RenderArtifacts`: a view render's registration data (frame,
  focus slots, mouse targets). `TestHelper#render_view(view_class, **assigns)`
  renders a view with no controller and returns `{frame:, focus_slots:,
  mouse_targets:}` for view unit specs.
- `slot :name { ... }` controller DSL: one declaration site for component
  identity. The factory is `instance_exec`'d against the controller (it can
  read `params`/`state`) and memoized for the screen's lifetime — replacing
  the `@query ||= ...` method idiom. Also defines a private reader named for
  the slot. With no explicit `focus_ring`, Tab cycles declared slots in
  declaration order; an explicit `focus_ring` still wins and may name
  component-less layout panes.
- `Charming::UnknownSlot`: raised when a rendered layout names a focusable
  pane nothing declares (no `slot`, no `focus_ring` entry, no same-named
  method), and for `on_submit`/`on_select`/`on_cancel` registrations
  referencing an undeclared slot — validated lazily at first dispatch so
  class-body order doesn't matter. Development/test raise; production logs.
- Data-refresh setters with selection clamping for the remaining memoizable
  pickers: `Tree#nodes=`, `TabBar#tabs=`, `Autocomplete#suggestions=`, and
  `MultiSelectList#items=` (which also drops out-of-range checks). Same
  two-halves idiom as `List#items=`/`Table#rows=`.
- `run_task(name, with: {...})`: task inputs travel in an explicit,
  deep-frozen hash. The block receives a `Charming::Tasks::Context` —
  `ctx[:key]` reads inputs, `ctx.report(...)` streams progress. Mutating a
  `with:` value inside the task raises `FrozenError`.
- `Charming::CrossThreadAccess`: raised when a task block calls `render`,
  `render_view`, `render_template`, `navigate`, `quit`, `session`, `focus`,
  or `component_for` from an executor thread, in development and test.
  Production logs a warning instead. (`session`'s checking wrapper is
  dev/test-only; production returns the raw hash.)
- `Charming::DoubleRenderError`: raised when a dispatch sets the response
  twice. `render`, `render_view`, `render_template`, `navigate`, and `quit`
  each assign the response; a second assignment raises with a message naming
  the action, the response already set, and the one attempted. A response set
  outside any dispatch (e.g. in `screen_entered`) is discarded on the next
  dispatch instead of raising.
- `bin/bench-render`: render-pipeline benchmark (80x24/200x60/400x110 frames;
  full-change, single-line, and 30fps animate workloads; ms/frame and
  allocations/frame). Measured 0.007 ms/frame median on the 200x60 animate
  workload, so the cell-buffer compositor is deferred (see ROADMAP.md).
- `Charming::Internal::Inflections`: internal string inflection helpers
  (`camelize`, `underscore`, `demodulize`, `deconstantize`, `constantize`,
  `humanize`, `pluralize`) with ActiveSupport-compatible semantics for the
  inputs Charming produces. `pluralize` covers a deliberate subset of English
  rules; exotic words may need a generated migration renamed by hand.
- `on_submit :slot, :action`, `on_select :slot, :action`, and
  `on_cancel :slot, :action` class DSL for declaring component-event handlers
  explicitly. Registrations inherit to subclasses like key bindings.
- `Charming::UnhandledComponentEvent`: raised when a component emits a result
  no handler covers, in development and test. Production logs a warning and
  keeps the old default-render fallback.
- `screen_entered` / `screen_exited` controller lifecycle hooks: they bracket
  the persistent controller instance's life. Override them to start and stop
  per-screen resources.
- `Charming::Shell::Sidebar` and `Charming::Shell::Palette`: the opt-in app
  shell (sidebar navigation, command palette, `command` DSL).
- `reset_form(:name)`: clears a form's controller-held draft state.
- `List#items=` and `Table#rows=`: replace a memoized component's data on
  render while its selection survives — the data-bound half of the
  persistent-controller component pattern.
- `Controller#component_dispatch` and `Controller#component_for(slot)`: the
  component-dispatch collaborator and the single slot-lookup point.

### Deprecated

- Resolving focus slots through same-named private methods
  (`def query; @query ||= ...; end`). Declare the component instead:
  `slot :query { ... }`. The convention still works but warns once per
  controller and slot (category `:undeclared_slot`). Scheduled for removal at
  1.0. Exception: form-builder methods (`def entry_form; form(:entry) ...; end`)
  and per-dispatch modal builders stay methods — they capture values that
  change between dispatches.
- `component_state` (still works, session-backed). Persistent controllers make
  it unnecessary: memoize components in ivars
  (`@query ||= Components::TextInput.new(...)`) for screen-lifetime state.
- `Controller.new(event:)`. Construct once, then pass events to the dispatch
  methods: `controller.dispatch_key(event)`.
- The auto-discovered `<slot>_submitted` / `<slot>_selected` /
  `<slot>_cancelled` hook convention. It still works but warns once per call
  site with the `on_*` declaration to add. Scheduled for removal at 1.0.

### Changed

- `save_session` never drops data silently anymore. State classes with no
  `persist` declarations and non-JSON-safe raw session values warn once per
  key/class (category `:session_drop`), naming the fix. At 1.0, undeclared
  means not persisted, with no warning. Previously state objects were skipped
  without any signal.
- Rendering is pure. `View#screen_layout` no longer mutates the controller
  (focus ring, mouse targets) mid-render; it stashes `RenderArtifacts` on the
  view. The dispatch pipeline merges them (last `screen_layout` wins for
  focus; mouse targets concatenate in render order), attaches them to the
  render response, and commits them once at dispatch exit. A dispatch that
  raises mid-render commits nothing, so the previous frame's registrations
  stay live. No app-facing API change.
- **Breaking:** Setting the response twice in one dispatch now raises
  `Charming::DoubleRenderError` instead of silently keeping the last write.
  Code that called `render` and then `navigate` (or any pair) in one action
  relied on the overwrite; delete the dead first call. A palette command that
  renders now keeps its own response instead of being overwritten by the
  default render. Migration: see UPGRADING.md.
- **Breaking:** The sidebar and command palette moved out of the controller
  kernel into an opt-in app shell. Include `Charming::Shell::Sidebar` and
  `Charming::Shell::Palette` in your `ApplicationController` to keep them;
  the `charming generate layout` generator adds the includes. The `command`
  class DSL moves with the palette module. Shell-less controllers handle keys,
  mouse, and tab traversal unchanged. Migration: see UPGRADING.md.
- Component dispatch is a collaborator (`Controller#component_dispatch`,
  mirroring `KeyDispatch`), and every dispatch path fetches slot components
  through one method, `Controller#component_for(slot)`.
- **Breaking:** Controllers are persistent per screen. The Runtime constructs
  one instance at route entry and dispatches every event at it —
  `dispatch_key(event)`, `dispatch_mouse(event)`, etc. take the event as an
  argument; `Controller.new(event:)` still works but warns. Instance variables
  now live for the screen's lifetime. Navigation discards the instance;
  `screen_entered`/`screen_exited` hooks bracket its life. Migration: see
  UPGRADING.md.
- Form state moved from `session[:forms]` to the controller instance. Clear a
  submitted form with the new `reset_form(:name)` instead of deleting session
  keys.
- Mouse hit-test targets (`register_mouse_targets`) live on the controller
  instance and are no longer written to the session.
- The rule for where state lives is now: controller ivars for screen-lifetime,
  `state(name, Klass)` objects for app-lifetime, `persist_session` for
  restart-lifetime.
- **Breaking:** `Charming::TestHelper#press`/`#press_sequence` take a controller
  instance (from `build_controller`) instead of a class, mirroring the
  persistent lifecycle: `press(ctrl, "enter")`.
- **Breaking:** Navigation is by screen name, not URL path.
  `navigate :project, id: 5` replaces `navigate_to "/projects/5"`.
  The controller helper is `navigate`. Migration: see UPGRADING.md.
- **Breaking:** `config/routes.rb` registers screens by name:
  `screen :projects, "projects#index"` replaces
  `screen "/projects", to: "projects#index"`. `root "home#show"` is unchanged
  and registers the reserved `:root` screen.
- Route params pass through with their Ruby values intact. No URL decoding,
  no string conversion: `navigate :entry, id: 5` yields `params[:id] == 5`.
- A string URL path passed to `screen` or `navigate` raises `ArgumentError`
  with a migration hint. `Router#resolve` on an unknown name raises `KeyError`
  listing the registered screen names.

### Removed

- The direct `activesupport` runtime dependency. `activemodel` remains and
  brings activesupport transitively. `Charming.env` now returns an internal
  `EnvInquirer` (same predicate API: `Charming.env.development?` etc.).
  No app-facing changes.
- **Breaking:** URL path templates (`/entries/:id`), dynamic-route regex
  matching, and percent-decoding. Register one named screen per parametric
  page and pass params at navigate time.
- **Breaking:** The `navigate_to` controller helper. Use `navigate`.
