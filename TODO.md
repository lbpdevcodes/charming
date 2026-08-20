# Charming TODO

Ruby TUI framework for Ruby 4+. Track of work to make this a proper production-ready framework.

## Priority 1 — Critical

- [x] Add mouse event support to TTYBackend
- [x] Add diffing renderer (or at minimum partial repaint option)
- [ ] Add API documentation and getting started guide
- [x] Add route parameters (`/users/:id`) for dynamic routing

## Priority 2 — Important

- [ ] `TextInput` rejects `theme:` — accept it like the other components (the theme-injection
      guide pushes apps toward passing `theme:` everywhere; gameroom hit this on 0.4.0 upgrade)
- [ ] Runtime graphics detection: query XTVERSION (like the OSC 11 background probe) so kitty
      graphics work over SSH when `TERM=xterm-256color` hides the terminal's identity —
      env-only detection sent gameroom's chess board to the glyph fallback over SSH
- [ ] Guard the kernel's `content_key_scope_active?` when the ring names `:content` without
      `Shell::Sidebar` — it calls the sidebar module's `content_focused?` and crashes a
      shell-less controller (gameroom worked around it by renaming the pane to `:body`)

- [x] Add Table component — most requested widget in TUI frameworks
- [x] Add Progressbar component
- [x] Add missing common widgets: checkbox (MultiSelectList), tabs (TabBar), status bar (StatusBar) — plus Tree, Toast, Badge, Breadcrumbs, HelpOverlay, Autocomplete
- [x] Add formal backend interface module instead of duck-typing
- [ ] Separate view state from application state (don't store Viewport/Spinner in session)
- [ ] Expand layout features: wrapping, clipping, vertical alignment — min/max dimensions done

## Priority 3 — Minor

- [x] Fix inconsistent key types (symbols for named keys, strings for characters)
- [ ] Fix generator templates — use template engine instead of string concatenation
- [x] Add CI/CD with GitHub Actions
- [x] Explicitly define `module Charming` in `lib/charming.rb`
- [x] Add fuzzy search to command palette (FuzzyMatcher, fzf-style scoring)
- [ ] Add property-based tests for UI styling system
- [ ] Add visual regression tests for rendered output
- [ ] Fill out `sig/charming.rbs` beyond `VERSION`

## Completed

- [x] Clean architecture with Application → Router → Controller → Model → View → Component → UI → Backend
- [x] Backend abstraction (TTYBackend, MemoryBackend)
- [x] Lip Gloss-inspired styling system
- [x] Generators for scaffolding
- [x] Command palette with filtering
- [x] Timer system with clock injection
- [x] Task executor and task events
- [x] View layouts and partial rendering
- [x] Themes loaded from bundled or app-local JSON
- [x] Table, progress bar, spinner, viewport, modal, list, text input, and activity indicator components
- [x] Comprehensive test suite with MemoryBackend
