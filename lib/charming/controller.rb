# frozen_string_literal: true

module Charming
  # Controller is the base class for all controller implementations in a Charming application.
  # It provides the action dispatch pipeline, key/timer/task bindings, component-event
  # declarations, and view rendering with layout composition. The sidebar and command
  # palette are opt-in: see Charming::Shell::Sidebar and Charming::Shell::Palette.
  #
  # Controllers are persistent per screen: the Runtime constructs one instance when a route is
  # entered and dispatches every event for that screen at it, so instance variables live for the
  # screen's lifetime. Use ivars for screen-lifetime state, `state(name, Klass)` objects for
  # app-lifetime state, and session persistence for restart-lifetime state.
  class Controller
    TimerBinding = Data.define(:name, :interval, :action, :autostart) do
      def initialize(name:, interval:, action:, autostart: true)
        super
      end
    end
    TaskBinding = Data.define(:name, :action)

    extend ClassMethods
    include ActionHooks
    include Rendering
    include SessionState
    include FocusManagement
    include Dispatching
    include Terminal
    include Timers

    attr_reader :application, :event, :params, :screen, :route

    # Initializes the controller with its parent application. The Runtime constructs one
    # instance per route entry; *event:* is deprecated — pass events to the dispatch
    # methods instead. Defaults to an 80x24 screen when no backend size is available.
    def initialize(application:, params: {}, screen: nil, route: nil, event: nil)
      if event
        Charming.deprecate(
          "Controller.new(event:) is deprecated. Construct the controller once and pass events " \
            "to the dispatch methods (e.g. dispatch_key(event)).",
          category: :controller_new_event
        )
      end
      @application = application
      @event = event
      @params = params
      @screen = screen || Screen.new(width: 80, height: 24)
      @route = route
      @response = nil
      @loop_thread = Thread.current
    end

    # Records the loop thread that owns this controller. Construction captures the
    # constructing thread; the Runtime re-captures when the event loop starts, covering
    # runtimes built on one thread and run on another. Internal — called by Runtime.
    def capture_loop_thread!
      @loop_thread = Thread.current
    end

    # Asserts the current thread is this controller's loop thread. The mutation funnels
    # (session, render/navigate/quit, focus, component_for) call this so task-block
    # access from an executor thread trips immediately. Raises CrossThreadAccess in
    # development and test; logs a warning in production. Internal — called by the
    # funnels and the session guard.
    def assert_loop_thread!(operation)
      return if Thread.current.equal?(@loop_thread)

      message = "A task thread called #{self.class.name || "an anonymous controller"}##{operation}. " \
        "Task blocks receive data in via `with:` and return data out as the block value. " \
        "Touch the controller, session, and components only on the loop thread — in the `on_task` handler."
      raise CrossThreadAccess, message unless Charming.env.production?

      logger.warn(message)
    end

    # Lifecycle hook called once after this controller becomes the active screen's
    # controller, before the first action dispatch. Start per-screen resources here.
    def screen_entered
    end

    # Lifecycle hook called before this controller is discarded — on navigation away or
    # at quit. Stop per-screen resources here.
    def screen_exited
    end

    # Replaces the screen dimensions after a terminal resize, keeping the live controller
    # instance (and its ivars) across the resize.
    def update_screen(screen)
      @screen = screen
    end

    # Dispatches a named action on this controller (e.g. :show), running all
    # before/around/after hooks and rescue_from handlers.
    def dispatch(action, event: nil)
      with_dispatch_state(event) do
        run_action_with_hooks(action)
        render_default_action if response.nil? && auto_render_after?(action)
        response || render("")
      end
    end

    # Key event dispatch. The precedence ladder (palette → focused text capture →
    # global bindings → overlay → sidebar/content/component) lives in KeyDispatch.
    def dispatch_key(event = nil)
      with_dispatch_state(event) { KeyDispatch.new(self).call }
    end

    # Timer event dispatcher: looks up the named action in timer bindings and runs it
    # with the full hook chain. Unlike #dispatch there is no render("") fallback — a
    # timer action that renders nothing yields a nil response, so silent ticks skip
    # the repaint instead of blanking the screen.
    def dispatch_timer(event = nil)
      with_dispatch_state(event) { timer_response }
    end

    # Task event dispatcher: looks up the handler in task bindings.
    def dispatch_task(event = nil)
      with_dispatch_state(event) { task_response(self.class.task_bindings) }
    end

    # Task progress dispatcher: looks up the handler in task progress bindings.
    def dispatch_task_progress(event = nil)
      with_dispatch_state(event) { task_response(self.class.task_progress_bindings) }
    end

    # Paste event dispatcher: forwards pasted text to the focused component's
    # `handle_paste` (TextInput, TextArea, Form text fields, and Autocomplete support it).
    def dispatch_paste(event = nil)
      with_dispatch_state(event) { paste_response }
    end

    # Mouse event dispatcher: command palette (if open) wins, then sidebar clicks
    # (route rows navigate directly), then named layout panes/components.
    def dispatch_mouse(event = nil)
      with_dispatch_state(event) { mouse_response }
    end

    # Renders a body or template wrapped in the controller's layout. Out-of-band escape sequences
    # registered while rendering (e.g. image transmissions) are collected by the Runtime around the
    # whole dispatch and attached to the response.
    def render(body = "", **assigns)
      assert_loop_thread!(:render)
      body = view_body(default_template_name(body), **assigns) if body.is_a?(Symbol)
      assign_response(Response.render(render_with_layout(body)), "render")
    end

    def render_view(view_class, **assigns)
      assert_loop_thread!(:render_view)
      assign_response(Response.render(render_with_layout(view_class.new(**template_assigns(assigns)))), "render_view(#{view_class})")
    end

    # Renders a template from `app/views` by name, applying the controller's layout. *name* is the
    # template path (e.g., "home/show") and additional keyword *assigns* are forwarded to the view.
    def render_template(name, **assigns)
      assert_loop_thread!(:render_template)
      assign_response(Response.render(render_with_layout(template_body(name, **assigns))), "render_template(#{name.inspect})")
    end

    # Returns the active theme for this request, delegated to the application.
    def theme
      application.theme
    end

    # Switches the active theme to *name* and persists the choice in the application session.
    def use_theme(name)
      application.use_theme(name)
    end

    # Returns the application logger. The default logger writes to File::NULL, so logging calls are
    # safe in TUI code unless the app explicitly configures a file or custom logger.
    def logger
      application.logger
    end

    # Navigates to the screen registered under *name* in config/routes.rb, passing
    # *params* through to the target controller (e.g. `navigate :project, id: project.id`).
    def navigate(name, **params)
      assert_loop_thread!(:navigate)
      assign_response(Response.navigate(name, **params), "navigate to :#{name}")
    end

    # Exits the application — sets a quit response that terminates the event loop.
    def quit
      assert_loop_thread!(:quit)
      assign_response(Response.quit, "quit")
    end

    # The component-dispatch collaborator: forwards key/mouse/paste events to focused
    # components and translates their results into controller action calls.
    def component_dispatch
      @component_dispatch ||= ComponentDispatch.new(self)
    end

    # Returns the component registered for the focus *slot*, or nil. Declared slots
    # (`slot :name { ... }`) resolve first, memoized per controller; undeclared slots
    # fall back to the same-named method convention. Every dispatch path fetches
    # components through here, so the slot convention is greppable in one place.
    def component_for(slot)
      assert_loop_thread!(:component_for)
      return declared_slot(slot.to_sym) if self.class.slot_definitions.key?(slot.to_sym)

      legacy_slot_component(slot)
    end

    private

    attr_reader :response

    # Returns the memoized component for a declared slot, instance_exec'ing the factory
    # on first access so it can read params and state. Factories that return nil are
    # memoized as nil (the key? check distinguishes "not built" from "built as nil").
    def declared_slot(name)
      @slots ||= {}
      return @slots[name] if @slots.key?(name)

      @slots[name] = instance_exec(&self.class.slot_definitions[name])
    end

    # Resolves an undeclared slot via the legacy same-named-method convention, warning
    # once per controller class and slot. Returns nil (without warning) when no such
    # method exists — pane names like :sidebar are slots without components.
    def legacy_slot_component(name)
      return nil unless respond_to?(name, true)

      Charming.deprecate(
        "#{self.class.name || "An anonymous controller"} resolves slot :#{name} via a private method. " \
          "Declare it instead: `slot :#{name} { ... }`. The convention is removed at 1.0.",
        category: :"undeclared_slot_#{self.class.name}_#{name}"
      )
      send(name)
    end

    # The single funnel through which every response is assigned. Raises
    # DoubleRenderError when a response was already set during this dispatch —
    # a second assignment would silently discard the first. Render responses carry
    # the dispatch's merged render artifacts (focus slots, mouse targets) for the
    # commit at dispatch exit.
    def assign_response(value, attempted)
      raise DoubleRenderError, double_render_message(attempted) if response

      @response = attach_render_artifacts(value)
    end

    # Attaches the merged render artifacts to a render response when any view rendered
    # a layout this dispatch. Non-render responses and layout-less renders carry none.
    def attach_render_artifacts(value)
      return value unless value.kind == :render
      return value if dispatch_render_artifacts.empty?

      value.with(artifacts: RenderArtifacts.merge(dispatch_render_artifacts))
    end

    # Commits the response's render artifacts: validates focus slots against the slot
    # registry, defines the layout focus scope, and registers mouse targets. Runs once
    # per dispatch, at the outermost exit — a dispatch that raises mid-render commits
    # nothing, so the previous frame's registrations stay live with what's on screen.
    def commit_render_artifacts
      artifacts = response&.artifacts
      return unless artifacts

      register_layout_focus(artifacts.focus_slots)
      register_mouse_targets(artifacts.mouse_targets)
    end

    # Builds the DoubleRenderError message, naming the action, the response
    # already set, the one attempted, and the fix.
    def double_render_message(attempted)
      "#{dispatch_context} set the response twice in one dispatch: " \
        "first #{describe_response(response)}, then #{attempted}. " \
        "Set the response once per dispatch: remove the first call or restructure the action."
    end

    # The controller and action for error messages (e.g. "HomeController#show").
    def dispatch_context
      name = self.class.name || "Anonymous controller"
      @current_action ? "#{name}##{@current_action}" : name
    end

    # A one-word description of a response for error messages.
    def describe_response(response)
      (response.kind == :navigate) ? "navigate to :#{response.name}" : response.kind.to_s
    end

    # Sets per-dispatch state (the event) around the block, then clears @response and
    # @event when the outermost dispatch exits, so per-dispatch state cannot leak
    # between events. Nested dispatches (a key binding calling #dispatch) keep it.
    # The outermost dispatch also clears @response on entry, so a response set outside
    # any dispatch (e.g. in screen_entered) is discarded instead of tripping the
    # DoubleRenderError guard on the next dispatch's first render. At the outermost
    # exit, a rendered response's artifacts commit; an exception skips the commit.
    def with_dispatch_state(event)
      @event = event if event
      @dispatch_depth = @dispatch_depth.to_i + 1
      if @dispatch_depth == 1
        @response = nil
        dispatch_render_artifacts.clear
        validate_slot_registrations_once
      end
      yield.tap { commit_render_artifacts if @dispatch_depth == 1 }
    ensure
      @dispatch_depth -= 1
      if @dispatch_depth.zero?
        @response = nil
        @event = nil
      end
    end

    # The timer binding's response, or nil when the ticked timer has no binding.
    def timer_response
      binding = self.class.timer_bindings[event.name.to_sym]
      return nil unless binding

      run_action_with_hooks(binding.action)
      response
    end

    # The task binding's response, or nil when the event name has no binding.
    def task_response(bindings)
      binding = bindings[event.name.to_sym]
      binding ? dispatch(binding.action) : nil
    end

    # Forwards the paste event to the focused component and dispatches its result.
    def paste_response
      slot = focus.current
      component = slot && component_for(slot)
      return nil unless component&.respond_to?(:handle_paste)

      result = component.handle_paste(event)
      return nil if result.nil?

      component_dispatch.dispatch_component_result(slot, result)
      response
    end

    # Routes the mouse event: palette first (when the app includes the shell palette),
    # then sidebar (likewise), then named panes/components.
    def mouse_response
      return dispatch_command_palette_mouse if respond_to?(:command_palette_open?) && command_palette_open?

      if respond_to?(:dispatch_sidebar_mouse, true)
        sidebar_response = dispatch_sidebar_mouse
        return sidebar_response if sidebar_response
      end

      component_dispatch.dispatch_component_mouse
    end
  end
end
