# Charming

[![CI](https://github.com/pandorocks/charming/actions/workflows/main.yml/badge.svg)](https://github.com/pandorocks/charming/actions/workflows/main.yml)

A Rails-inspired terminal user interface framework for **Ruby 4+**.

Charming gives terminal apps familiar application structure: routes, controllers, state objects, templates, layouts, reusable components, themes, keyboard bindings, command palettes, timers, physics-based animation (springs and projectiles, ported from charmbracelet/harmonica), background tasks, cross-platform audio playback, inline image display (Kitty graphics protocol), system clipboard / desktop notifications / window title, braille charts and sparklines, and testable terminal backends.

## Project Status

Charming is still in its infancy and is under constant development. APIs, behavior, and generated app structure may change until the project reaches a stable `1.0` release.

[API_POLICY.md](API_POLICY.md) defines what the 1.0 freeze covers: `Charming::Internal` is unversioned, and everything else follows semver from 1.0.

## Quick Start

Install the Charming CLI gem on your machine:

```bash
gem install charming
```

Generate and run an app:

```bash
charming new my_app
cd my_app
bundle install
bundle exec exe/my_app
```

Charming can also be added to an existing Ruby project with Bundler, but the primary workflow is installing the gem globally and using `charming new` to create a complete app.

## Documentation

- [Docs](https://charming.sh)

## Generated App Structure

The generator produces a Bundler gem with a Rails-like structure:

```text
app/controllers/                         # controller actions and input bindings
app/state/                               # session-backed TUI state
app/models/                              # optional Active Record models
app/views/                               # screen view classes
app/views/layouts/application_layout.rb  # layout view class
app/components/                          # reusable components
config/routes.rb                         # route definitions
lib/my_app.rb                            # namespace loader (Zeitwerk)
exe/my_app                               # executable entry point
```

Generated apps start minimal. Until the app defines a route, it boots to a built-in welcome screen served from the gem itself (like Rails' welcome page) — generate your first screen and it disappears, with nothing to delete:

```bash
bundle exec charming generate screen home
```

Restore the full app chrome — sidebar/content layout, command palette (`ctrl+p`), focus management, and theme switching — with one command:

```bash
bundle exec charming generate layout --style sidebar
```

## Development

After checking out the repo, run:

```bash
bundle install
bin/check
```

Common binstubs:

```bash
bin/rspec             # run specs only
bin/format            # auto-format with Standard Ruby
bin/lint              # style checks with Standard Ruby
bin/check             # run everything
bin/ci                # what CI runs: specs, lint, eager-load check, gem build
```
