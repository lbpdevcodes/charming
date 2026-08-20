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

- The auto-discovered `<slot>_submitted` / `<slot>_selected` /
  `<slot>_cancelled` hook convention. It still works but warns once per call
  site with the `on_*` declaration to add. Scheduled for removal at 1.0.

### Changed

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
