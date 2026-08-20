# frozen_string_literal: true

module Charming
  # Runtime manages a terminal UI application's lifecycle: setting up an
  # alternative-screen terminal with cursor hiding, running an event loop that
  # reads keyboard, mouse, timer, and task events, dispatching them to
  # controllers, rendering responses, and tearing down cleanly on exit.
  class Runtime
    DEFAULT_READ_TIMEOUT = Internal::EventLoop::DEFAULT_READ_TIMEOUT

    def initialize(application, backend: nil, renderer: nil, clock: nil, task_executor: nil)
      @application = application
      @backend = backend || Internal::Terminal::TTYBackend.new
      @renderer = renderer || Internal::Renderer::Differential.new(@backend)
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @task_queue = Thread::Queue.new
      @task_executor = build_task_executor(task_executor)
      @application.task_executor = @task_executor
      @route = resolve_route(:root)
      @screen = backend_screen
      @coalesce_input = @application.respond_to?(:coalesce_input?) && @application.coalesce_input?
      @event_loop = build_event_loop
      @application.timer_control = Internal::TimerControl.new(
        event_loop: @event_loop,
        bindings: -> { @route.controller_class.timer_bindings }
      )
      enter_controller
    end

    # Runs the event loop: enters alt-screen, dispatches incoming events
    # (key, mouse, timer, async task), renders controller responses, and
    # restores terminal state on exit. Unhandled exceptions from controller
    # actions render an ErrorScreen instead of crashing the terminal.
    def run
      setup_terminal
      install_signal_handlers
      install_exit_hook
      with_raw_input do
        render(initial_response)
        @event_loop.run { |event, more_ready| process(event, flush: !more_ready) }
      ensure
        exit_controller
        restore_signal_handlers
        @task_executor&.shutdown(timeout: 2.0)
        @application.save_session if @application.respond_to?(:save_session)
        restore_terminal
      end
    end

    private

    attr_reader :screen

    # Builds the event pump, wiring in the current controller's timer bindings and
    # an interrupt check backed by the SIGINT flag set in install_interrupt_handler.
    def build_event_loop
      Internal::EventLoop.new(
        backend: @backend,
        clock: @clock,
        task_queue: @task_queue,
        timer_bindings: autostart_timer_bindings,
        coalesce_input: @coalesce_input,
        interrupted: -> { @interrupted }
      )
    end

    # The current route's timers that run from boot. Timers declared with
    # `autostart: false` (including `animate` ticks) wait for `start_timer`.
    def autostart_timer_bindings
      @route.controller_class.timer_bindings.values.select(&:autostart)
    end

    # The first frame's response — the root route's action, with errors caught. Out-of-band escape
    # sequences registered while rendering are collected and attached to the response.
    def initial_response
      response = nil
      escapes = Escape.collecting { response = resolve_response(dispatch(@route.action)) }
      attach_escapes(response, escapes)
    rescue => e
      error_response(e)
    end

    # Handles a single event. Returns :quit to stop the loop, nil otherwise.
    # While an error screen is showing, only key events are honored: q quits,
    # any other key dismisses and re-renders the current route. When *flush* is
    # false (more events are already due), the response is held so a burst of
    # task/timer events paints once with the final state; held escapes are
    # carried forward in order so none are lost.
    def process(event, flush: true)
      return process_error_event(event) if @error
      return :quit if unbound_interrupt?(event)

      response = nil
      escapes = Escape.collecting do
        response = dispatch_event(event)
        response = resolve_response(response) if response
      end
      return flush_pending if response.nil?
      return :quit if response.quit?

      hold_response(response, escapes)
      flush ? flush_pending : nil
    rescue => e
      @pending_response = nil
      render(error_response(e))
      nil
    end

    # Replaces the held response with *response*, prepending any escapes held
    # from earlier events in the burst so they still flush in order.
    def hold_response(response, escapes)
      held = @pending_response&.escapes || []
      @pending_response = response.with(escapes: held + response.escapes + escapes)
    end

    # Renders the held response, if any. Always returns nil (the loop's "keep going").
    def flush_pending
      response = @pending_response
      @pending_response = nil
      render(response) if response
      nil
    end

    # Error-mode event handling: q quits, any other key dismisses the error
    # and re-dispatches the current route's action. Timer/task events are ignored.
    def process_error_event(event)
      return unless event.is_a?(Events::KeyEvent)
      return :quit if Charming.key_of(event) == :q

      @error = nil
      render(initial_response)
      nil
    end

    # True for a Ctrl+C key press that the current controller has no binding for —
    # the runtime treats it as quit so apps always have an escape hatch. Controllers
    # can take over by binding "ctrl+c" themselves.
    def unbound_interrupt?(event)
      return false unless event.is_a?(Events::KeyEvent)
      return false unless event.ctrl && event.key == :c

      @route.controller_class.key_bindings[:"ctrl+c"].nil?
    end

    # Signals that should exit the loop cleanly through the ensure block (restoring
    # the terminal) instead of killing the process mid-frame.
    QUIT_SIGNALS = %w[INT TERM HUP].freeze

    # Traps quit signals to set the interrupt flag the event loop checks, and —
    # when the backend supports it — SIGTSTP/SIGCONT for shell suspend/resume.
    def install_signal_handlers
      @interrupted = false
      @previous_handlers = {}
      QUIT_SIGNALS.each { |signal| trap_signal(signal) { @interrupted = true } }
      install_suspend_handlers if @backend.respond_to?(:suspend)
    end

    # Ctrl+Z: return the terminal to its normal state, stop the process, and on
    # SIGCONT re-enter the TUI and force a repaint via the backend's resize path.
    def install_suspend_handlers
      trap_signal("TSTP") { suspend }
      trap_signal("CONT") { resume }
    end

    # Traps *signal*, remembering the previous handler for teardown. Platforms
    # without the signal (or restricted environments) are silently skipped.
    def trap_signal(signal, &block)
      @previous_handlers[signal] = Signal.trap(signal, &block)
    rescue ArgumentError
      @previous_handlers.delete(signal)
    end

    # Restores every signal handler that was replaced when the runtime started.
    def restore_signal_handlers
      (@previous_handlers || {}).each do |signal, previous|
        Signal.trap(signal, previous || "DEFAULT")
      rescue ArgumentError
        nil
      end
    end

    # Restores the terminal for the shell and stops the process (the untrappable
    # SIGSTOP), so Ctrl+Z behaves like it does in any well-behaved TUI.
    def suspend
      @backend.suspend
      Process.kill("STOP", Process.pid)
    end

    # Re-enters the TUI after a foreground `fg`: raw mode and alt screen come back,
    # the renderer cache is dropped, and the backend's resize path triggers a repaint.
    def resume
      @backend.resume
      @renderer.invalidate if @renderer.respond_to?(:invalidate)
      @backend.notify_resize if @backend.respond_to?(:notify_resize)
    end

    # Registers a process-exit fallback so an unexpected death (an exception that
    # skips run's ensure, or an exit from within a handler) still restores the
    # terminal. restore_terminal is idempotent, so the normal path stays cheap.
    def install_exit_hook
      return if @exit_hook_installed

      @exit_hook_installed = true
      at_exit { restore_terminal }
    end

    # Records *error*, logs its backtrace, and builds a centered ErrorScreen response.
    def error_response(error)
      @error = error
      @application.logger.error("#{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}")
      panel = Components::ErrorScreen.new(error: error, theme: @application.theme).render
      Response.render(UI.center(panel, width: screen.width, height: screen.height))
    end

    # Dispatches an action on the current route's controller with an optional event.
    # Entry point from the event loop into controllers.
    def dispatch(action, event: nil)
      @controller.dispatch(action, event: event)
    end

    # Dispatches a key press to the current route's controller.
    def dispatch_key(event)
      @controller.dispatch_key(event)
    end

    # Dispatches a timer tick to the current route's controller.
    def dispatch_timer(event)
      @controller.dispatch_timer(event)
    end

    # Dispatches an async task result to the current route's controller.
    def dispatch_task(event)
      @controller.dispatch_task(event)
    end

    # Dispatches a task progress report to the current route's controller.
    def dispatch_task_progress(event)
      @controller.dispatch_task_progress(event)
    end

    # Dispatches a mouse action (click, drag, scroll) to the current route's controller.
    def dispatch_mouse(event)
      @controller.dispatch_mouse(event)
    end

    # Constructs the controller for the current route and runs its screen_entered hook.
    # The instance lives until the next navigation (or quit), so controller ivars hold
    # screen-lifetime state.
    def enter_controller
      @controller = @route.controller_class.new(
        application: @application, params: @route.params, screen: screen, route: @route
      )
      @controller.screen_entered
    end

    # Runs the current controller's screen_exited hook and releases it.
    def exit_controller
      @controller&.screen_exited
      @controller = nil
    end

    # Type-based dispatcher: routes resize, task, progress, timer, mouse, paste, and key
    # events to the appropriate handler. Falls back to key dispatch for unclassified events.
    def dispatch_event(event)
      return dispatch_resize(event) if event.is_a?(Events::ResizeEvent)
      return dispatch_task(event) if event.is_a?(Events::TaskEvent)
      return dispatch_task_progress(event) if event.is_a?(Events::TaskProgressEvent)
      return dispatch_timer(event) if event.is_a?(Events::TimerEvent)
      return dispatch_mouse(event) if event.is_a?(Events::MouseEvent)
      return dispatch_paste(event) if event.is_a?(Events::PasteEvent)
      return dispatch_focus_change(event) if event.is_a?(Events::FocusEvent)

      dispatch_key(event)
    end

    # Dispatches a terminal focus change to the controller's optional `focus_changed`
    # action. Ignored when the controller doesn't define one.
    def dispatch_focus_change(event)
      return nil unless @controller.respond_to?(:focus_changed)

      @controller.dispatch(:focus_changed, event: event)
    end

    # Dispatches pasted text to the current route's controller.
    def dispatch_paste(event)
      @controller.dispatch_paste(event)
    end

    # Dispatches a resize event: updates screen dimensions on the live controller and
    # re-renders the current action.
    # The renderer's cached previous frame is invalidated and the backend is cleared so the
    # new-dimension frame paints onto a clean alt-screen instead of overlaying stale rows.
    def dispatch_resize(event)
      @screen = Screen.new(width: event.width, height: event.height)
      @renderer.invalidate if @renderer.respond_to?(:invalidate)
      @backend.clear if @backend.respond_to?(:clear)
      @controller.update_screen(@screen)
      dispatch(@route.action, event: event)
    end

    # Follows navigation responses: discards the current controller, resolves and enters
    # the new route, reschedules the event loop's timers for the new controller, and
    # dispatches that route's action.
    def resolve_response(response)
      return response unless response.navigate?

      exit_controller
      @route = resolve_route(response.name, response.params)
      @event_loop.reset_timers(autostart_timer_bindings)
      enter_controller
      dispatch(@route.action)
    end

    # Resolves *name* from the app's router, attaching *params*. An unrouted :root falls
    # back to the app's first route, or to the built-in welcome screen when no screens
    # are defined yet (like Rails' welcome page); other unrouted names still raise.
    def resolve_route(name, params = {})
      @application.routes.resolve(name, params)
    rescue KeyError
      raise unless name.to_sym == :root

      (@application.routes.all.first || Welcome.route).with_params(params)
    end

    # Derives Screen dimensions (width, height) from the terminal backend.
    def backend_screen
      width, height = @backend.size
      Screen.new(width: width, height: height)
    end

    # Renders a response: first flushes any out-of-band escape sequences (image transmissions,
    # clipboard writes, notifications, title changes) straight to the backend — ahead of the frame so
    # image data is registered before its placeholder cells reference it — then renders the body.
    def render(response)
      flush_escapes(response)
      @renderer.render(response.body)
    end

    # Writes a response's out-of-band escape sequences to the backend, ahead of the frame. No-op for
    # backends that don't support them or responses that carry none.
    def flush_escapes(response)
      return unless @backend.respond_to?(:write_escape)

      response.escapes&.each { |sequence| @backend.write_escape(sequence) }
    end

    # Returns *response* with *escapes* appended, or unchanged when none were collected.
    def attach_escapes(response, escapes)
      return response if escapes.nil? || escapes.empty?

      response.with(escapes: response.escapes + escapes)
    end

    # Constructs a task executor: supports explicit instances, callable factories, or the default Threaded executor.
    def build_task_executor(task_executor)
      return Tasks::ThreadedExecutor.new(@task_queue) unless task_executor
      return task_executor if task_executor.respond_to?(:submit)
      return task_executor.call(@task_queue) if task_executor.respond_to?(:call) && !task_executor.respond_to?(:new)

      task_executor.new(@task_queue)
    end

    # Returns the clock proc, providing a single point of access for time in the event loop.
    def clock_now
      @clock.call
    end

    # Enters an alternative screen buffer, hides the cursor, and installs
    # a terminal resize signal handler if supported by the backend. Also asks
    # the terminal for its background color so adaptive colors resolve correctly.
    def setup_terminal
      detect_background
      @backend.enter_alt_screen
      @backend.hide_cursor
      @backend.enable_mouse_tracking(motion: mouse_motion) if @backend.respond_to?(:enable_mouse_tracking)
      @backend.enable_bracketed_paste if @backend.respond_to?(:enable_bracketed_paste)
      @backend.enable_focus_reporting if @backend.respond_to?(:enable_focus_reporting)
      @backend.install_resize_handler if @backend.respond_to?(:install_resize_handler)
    end

    # The app's configured mouse motion mode (:drag unless the app opts into :all hover).
    def mouse_motion
      @application.respond_to?(:mouse_motion) ? @application.mouse_motion : :drag
    end

    # Feeds the terminal's OSC 11 background reply (when the backend can obtain
    # one) into UI::Background so adaptive colors resolve against reality rather
    # than the dark-background default.
    def detect_background
      return unless @backend.respond_to?(:query_background_color)

      background = @backend.query_background_color
      UI::Background.assume = background if background
    end

    # Keeps input raw/no-echo across rendering and dispatch, not just during reads.
    def with_raw_input(&block)
      return yield unless @backend.respond_to?(:with_raw_input)

      @backend.with_raw_input(&block)
    end

    # Restores terminal state: reinstalls any previous resize handler, shows
    # the cursor, and leaves the alternative screen buffer. Idempotent — runs
    # once whether reached from run's ensure or the at_exit fallback.
    def restore_terminal
      return if @restored

      @restored = true
      @backend.restore_resize_handler if @backend.respond_to?(:restore_resize_handler)
      @backend.disable_focus_reporting if @backend.respond_to?(:disable_focus_reporting)
      @backend.disable_bracketed_paste if @backend.respond_to?(:disable_bracketed_paste)
      @backend.disable_mouse_tracking if @backend.respond_to?(:disable_mouse_tracking)
      @backend.show_cursor
      @backend.leave_alt_screen
    end
  end
end
