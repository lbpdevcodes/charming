# frozen_string_literal: true

module Charming
  class Controller
    # Session-state helpers mixed into Controller: accessing the application session hash, lazy
    # state-object lookup by name/class, form builder invocation, and async task submission.
    #
    # State-lifetime rule of thumb: controller ivars for screen-lifetime, `state` objects for
    # app-lifetime, session-persisted values (`persist_session`) for restart-lifetime.
    module SessionState
      # Returns the application session hash for this controller. The session holds state that
      # must outlive a screen: `state` objects, app-global UI state (focus rings, sidebar index,
      # command palette), and values persisted across restarts via `persist_session`.
      # In development and test the hash is wrapped in an Internal::SessionGuard so access
      # from a task executor thread raises CrossThreadAccess; production returns the raw hash.
      def session
        return application.session if Charming.env.production?

        @session_guard ||= Internal::SessionGuard.new(application.session, self)
      end

      # Stores the named layout panes from the latest render so mouse events can be hit-tested
      # against the same focus slots used by Tab traversal. Kept on the controller instance:
      # mouse targets describe the latest render, not persistent state.
      def register_mouse_targets(targets)
        @mouse_targets = targets
      end

      # Returns the named layout panes from the latest render.
      def mouse_targets
        @mouse_targets || []
      end

      # Returns the named session-backed state object, creating it on first access. *name* is a
      # symbol key under `session[:states]`. *state_class* is an ApplicationState subclass whose
      # constructor receives *attributes* on first creation. Subsequent calls return the same object.
      def state(name, state_class, **attributes)
        session[:states] ||= {}
        session[:states][name.to_sym] ||= state_class.new(**attributes)
      end

      # Deprecated. Returns the named mutable widget-state hash stored under
      # `session[:component_state]`, seeding it from *defaults* on first access.
      # Persistent controllers make this unnecessary: memoize the component in an ivar
      # (`@query ||= Components::TextInput.new(...)`) for screen-lifetime state instead.
      def component_state(name, **defaults)
        Charming.deprecate(
          "component_state is deprecated. Persistent controllers keep components for the screen's " \
            "lifetime — memoize them in ivars (`@query ||= Components::TextInput.new(...)`).",
          category: :component_state
        )
        session[:component_state] ||= {}
        session[:component_state][name.to_sym] ||= defaults
      end

      # Builds a Form component scoped to the named form slot. The form's mutable state hash
      # lives on the controller instance: it survives events on this screen and is discarded
      # on navigation. Clear it after a successful submit with `reset_form`.
      def form(name, &block)
        builder = Components::Form::Builder.new(theme: theme)
        block.arity.zero? ? builder.instance_eval(&block) : block.call(builder)
        builder.build(state: form_states[name.to_sym] ||= {}, theme: theme)
      end

      # Clears the named form's stored state (e.g. after a successful submit, or when the
      # form should re-seed from fresh defaults).
      def reset_form(name)
        form_states.delete(name.to_sym)
      end

      # The per-controller store of form state hashes, keyed by form name.
      def form_states
        @form_states ||= {}
      end

      # Submits a background task with the given *name*. The block is executed by the configured
      # task executor; its return value (or any raised exception) is delivered to the controller
      # as a TaskEvent dispatched to the matching `on_task` handler.
      #
      # Blocks that accept an argument receive a Tasks::Context: `ctx[key]` reads inputs from
      # the *with:* hash (deep-frozen at submit time) and `ctx.report(...)` dispatches the
      # matching `on_task_progress` handler. *timeout:* (seconds) cancels the task with
      # Tasks::Cancelled when exceeded.
      #
      # Task blocks receive data in via *with:* and return data out as the block value; they
      # touch nothing else. The `on_task` handler on the loop thread is the only place task
      # results become state.
      def run_task(name, timeout: nil, with: {}, &block)
        block = task_block_wrapper(block, Internal::DeepFreeze.call(with))
        return application.task_executor.submit(name, timeout: timeout, &block) if timeout

        # Without a timeout, use the plain signature so simple custom executors
        # (`def submit(name, &block)`) remain compatible.
        application.task_executor.submit(name, &block)
      end

      # Cancels the named in-flight background task (raises Tasks::Cancelled inside it).
      # No-op when the task already finished or the executor doesn't support cancellation.
      def cancel_task(name)
        executor = application.task_executor
        executor.cancel(name) if executor.respond_to?(:cancel)
      end

      private

      # Wraps the task block so it receives a Tasks::Context carrying the *with* data
      # plus the executor's progress reporter. The wrapper's arity is always 1, so the
      # executor hands it the reporter; the original block's arity decides whether the
      # context is passed on (lambdas stay strict).
      def task_block_wrapper(block, data)
        proc do |progress|
          context = Tasks::Context.new(data, progress)
          block.arity.zero? ? block.call : block.call(context)
        end
      end
    end
  end
end
