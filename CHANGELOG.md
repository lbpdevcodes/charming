# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Deprecated

- `component_state` (still works, session-backed). Persistent controllers make
  it unnecessary: memoize components in ivars
  (`@query ||= Components::TextInput.new(...)`) for screen-lifetime state.
- `Controller.new(event:)`. Construct once, then pass events to the dispatch
  methods: `controller.dispatch_key(event)`.
- The auto-discovered `<slot>_submitted` / `<slot>_selected` /
  `<slot>_cancelled` hook convention. It still works but warns once per call
  site with the `on_*` declaration to add. Scheduled for removal at 1.0.

### Changed

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
