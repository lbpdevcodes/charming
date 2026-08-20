# API Policy

This file defines the stability contract for the Charming public API. The docs
site carries the longer version under `docs/api/stability.md`; both change
together.

## The rule

- Everything under `Charming::Internal` is unversioned. It can change in any
  release without notice. Do not build on it.
- Everything else follows semantic versioning from 1.0. Breaking changes need
  a deprecation release first.
- Constants outside `Internal` whose docstring says "Internal" (dispatch
  collaborators such as `Controller::KeyDispatch`, layout node internals) are
  public for structural reasons only. They follow the Internal rule.

## The public surface

From 1.0, semver covers:

- The controller DSL: `key`, `timer`, `animate`, `on_task`, `on_task_progress`,
  `on_submit`/`on_select`/`on_cancel`, `slot`, `focus_ring`, `layout`,
  `auto_render`, `before_action`/`after_action`/`around_action`, `rescue_from`.
- The controller action API: `render`, `render_view`, `render_template`,
  `navigate`, `quit`, `session`, `state`, `form`/`reset_form`, `run_task`,
  `cancel_task`, `start_timer`/`stop_timer`, `screen_entered`/`screen_exited`.
- The slot/focus/dispatch contracts: `focus`, `focused?`, `component_for`, and
  the `Charming::Components::Result` return protocol for component
  `handle_key`/`handle_mouse`/`handle_paste` (legacy forms normalize).
- View helpers: assigns readers, `text`, `box`, `row`, `column`,
  `render_component`, `screen_layout`, `yield_content`.
- The Router DSL (`root`, `screen`, `navigate` by name), `Response`,
  `Charming::Events::*`, `Charming::Screen`.
- `Charming::TestHelper`, the `Charming::Shell` modules, `Charming::Tasks`
  (executors, `Context`, `Cancelled`), and the built-in `Charming::Components`.
- Error classes: `Error`, `UnhandledComponentEvent`, `UnknownSlot`,
  `DoubleRenderError`, `CrossThreadAccess`.

## Drift control

`rake api:public` lists every public constant. `spec/api_policy_spec.rb` locks
the list: adding or removing a public constant fails the suite until the PR
updates the list, so API drift shows up in review.
