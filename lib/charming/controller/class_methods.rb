# frozen_string_literal: true

module Charming
  class Controller
    # DSL for declaring controller-level event bindings and configuration: keys, commands,
    # timers, task handlers, the auto-rendered action, layout wrapper, and focus ring.
    # Mixed into Controller as class methods; also exposed for tests and shared base controllers.
    module ClassMethods
      # Binds a key press to a controller action. *name* is the normalized key symbol (e.g., "up",
      # "q", "ctrl+c"). *scope* is :content (default) for content-pane keys or :global for app-wide
      # shortcuts that fire regardless of focus. Raises ArgumentError for any other scope.
      def key(name, action, scope: :content)
        normalized_scope = validate_key_scope(scope)
        key_name = Charming.key_binding_name(name)
        key_bindings[key_name] = action
        key_binding_scopes[key_name] = normalized_scope
      end

      # Adds a CommandPalette entry with the given *label*. *action* is a method name to send on
      # the controller, or a block to instance_exec when selected.
      def command(label, action = nil, &block)
        command_bindings << Components::CommandPalette::Command.new(label: label, value: block || action)
      end

      # Declares a timer that fires every *every* seconds and dispatches *action* on the controller.
      # The runtime builds a TimerEvent and routes it to the active controller's dispatch_timer.
      # Timers run from boot by default; declare `autostart: false` to schedule one only when an
      # action calls `start_timer`.
      def timer(name, every:, action:, autostart: true)
        raise ArgumentError, "timer interval must be positive (got #{every.inspect})" unless every.is_a?(Numeric) && every.positive?

        timer_bindings[name.to_sym] = TimerBinding.new(name: name.to_sym, interval: every, action: action, autostart: autostart)
      end

      # Declares an animation: a stopped timer ticking *action* at *fps* frames per second.
      # Begin motion with `start_timer(name)`; the action calls `stop_timer(name)` once the
      # motion settles, returning the app to zero idle cost.
      def animate(name, action:, fps: 30)
        raise ArgumentError, "fps must be positive (got #{fps.inspect})" unless fps.is_a?(Numeric) && fps.positive?

        timer(name, every: 1.0 / fps, action: action, autostart: false)
      end

      # Declares a task handler for async work submitted via `run_task(:name)`. When the task emits
      # a TaskEvent with the matching name, the runtime dispatches *action* on the controller.
      def on_task(name, action:)
        task_bindings[name.to_sym] = TaskBinding.new(name: name.to_sym, action: action)
      end

      # Declares a progress handler for a task: while `run_task(:name)` runs, each
      # `progress.report(...)` dispatches *action* on the controller (the event is
      # available as `event` — a TaskProgressEvent with current/total/message).
      def on_task_progress(name, action:)
        task_progress_bindings[name.to_sym] = TaskBinding.new(name: name.to_sym, action: action)
      end

      # Declares the action dispatched when the component in *slot* submits a value
      # (`[:submitted, value]` from its `handle_key`). The action receives the value.
      def on_submit(slot, action)
        component_event_bindings[[slot.to_sym, :submitted]] = action.to_sym
      end

      # Declares the action dispatched when the component in *slot* selects an item
      # (`[:selected, value]` from its `handle_key`). The action receives the value.
      def on_select(slot, action)
        component_event_bindings[[slot.to_sym, :selected]] = action.to_sym
      end

      # Declares the action dispatched when the component in *slot* is cancelled
      # (`:cancelled` from its `handle_key`). The action receives no arguments.
      def on_cancel(slot, action)
        component_event_bindings[[slot.to_sym, :cancelled]] = action.to_sym
      end

      # Sets the action that the controller should auto-render after a non-rendering action runs.
      # Defaults to :show when unset.
      def auto_render(action = :show)
        @auto_render_action = action.to_sym
      end

      # Returns the configured auto-render action, walking the superclass chain when undefined locally.
      def auto_render_action
        return @auto_render_action if instance_variable_defined?(:@auto_render_action)
        return superclass.auto_render_action if superclass.respond_to?(:auto_render_action)

        nil
      end

      # Sets or returns the controller's layout. Pass a layout class (instantiated per request),
      # a String/Symbol template name (resolved through Templates), or `false` to
      # disable inherited layout wrapping. Called with no arguments returns the resolved layout.
      def layout(layout_class = :__charming_layout_reader__)
        return resolved_layout if layout_class == :__charming_layout_reader__

        @layout = layout_class
      end

      # Hash of registered key bindings (symbol key name => action method name), inherited from
      # superclass controllers.
      def key_bindings
        @key_bindings ||= superclass.respond_to?(:key_bindings) ? superclass.key_bindings.dup : {}
      end

      # Hash of key scopes paralleling `key_bindings` (symbol key name => :content or :global).
      def key_binding_scopes
        @key_binding_scopes ||= superclass.respond_to?(:key_binding_scopes) ? superclass.key_binding_scopes.dup : {}
      end

      # Defines the named focus slots cycled by Tab/Shift+Tab traversal.
      def focus_ring(*slots)
        @focus_ring_slots = slots
      end

      # Returns the focus ring slots, inherited from superclass when undefined.
      def focus_ring_slots
        @focus_ring_slots ||= superclass.respond_to?(:focus_ring_slots) ? superclass.focus_ring_slots.dup : []
      end

      # Array of registered command palette entries, inherited from superclass when undefined.
      def command_bindings
        @command_bindings ||= superclass.respond_to?(:command_bindings) ? superclass.command_bindings.dup : []
      end

      # Hash of timer name => TimerBinding, inherited from superclass when undefined.
      def timer_bindings
        @timer_bindings ||= superclass.respond_to?(:timer_bindings) ? superclass.timer_bindings.dup : {}
      end

      # Hash of task name => TaskBinding, inherited from superclass when undefined.
      def task_bindings
        @task_bindings ||= superclass.respond_to?(:task_bindings) ? superclass.task_bindings.dup : {}
      end

      # Hash of task name => TaskBinding for progress handlers, inherited from superclass.
      def task_progress_bindings
        @task_progress_bindings ||= superclass.respond_to?(:task_progress_bindings) ? superclass.task_progress_bindings.dup : {}
      end

      # Hash of [slot, event] => action for component-event registrations made with
      # `on_submit`/`on_select`/`on_cancel`, inherited from superclass when undefined.
      def component_event_bindings
        @component_event_bindings ||= superclass.respond_to?(:component_event_bindings) ? superclass.component_event_bindings.dup : {}
      end

      private

      # Validates that *scope* is :content or :global; otherwise raises ArgumentError.
      def validate_key_scope(scope)
        normalized_scope = scope.to_sym
        return normalized_scope if %i[content global].include?(normalized_scope)

        raise ArgumentError, "unknown key scope: #{scope.inspect}"
      end

      # Walks the superclass chain to find a configured layout, returning nil if none is set.
      def resolved_layout
        return @layout if instance_variable_defined?(:@layout)
        return superclass.layout if superclass.respond_to?(:layout)

        nil
      end
    end
  end
end
