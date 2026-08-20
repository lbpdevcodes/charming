# frozen_string_literal: true

module Charming
  # Controller is the base class for all controller implementations in a Charming application.
  # It provides the action dispatch pipeline, key/command/timer/task bindings, sidebar navigation,
  # command palette management, and view rendering with layout composition.
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
    include SidebarNavigation
    include CommandPalette
    include ComponentDispatching
    include Dispatching
    include Terminal
    include Timers

    attr_reader :application, :event, :params, :screen, :route

    # Initializes the controller with its parent application and optional event.
    # Defaults to an 80x24 screen when no backend size is available.
    def initialize(application:, event: nil, params: {}, screen: nil, route: nil)
      @application = application
      @event = event
      @params = params
      @screen = screen || Screen.new(width: 80, height: 24)
      @route = route
      @response = nil
    end

    # Dispatches a named action on this controller (e.g. :show), running all
    # before/around/after hooks and rescue_from handlers.
    def dispatch(action)
      run_action_with_hooks(action)
      render_default_action if response.nil? && auto_render_after?(action)
      response || render("")
    end

    # Key event dispatch. The precedence ladder (palette → focused text capture →
    # global bindings → overlay → sidebar/content/component) lives in KeyDispatch.
    def dispatch_key
      KeyDispatch.new(self).call
    end

    # Timer event dispatcher: looks up the named action in timer bindings and runs it
    # with the full hook chain. Unlike #dispatch there is no render("") fallback — a
    # timer action that renders nothing yields a nil response, so silent ticks skip
    # the repaint instead of blanking the screen.
    def dispatch_timer
      b = self.class.timer_bindings[event.name.to_sym]
      return nil unless b

      run_action_with_hooks(b.action)
      response
    end

    # Task event dispatcher: looks up the handler in task bindings.
    def dispatch_task
      b = self.class.task_bindings[event.name.to_sym]
      b ? dispatch(b.action) : nil
    end

    # Task progress dispatcher: looks up the handler in task progress bindings.
    def dispatch_task_progress
      b = self.class.task_progress_bindings[event.name.to_sym]
      b ? dispatch(b.action) : nil
    end

    # Paste event dispatcher: forwards pasted text to the focused component's
    # `handle_paste` (TextInput, TextArea, Form text fields, and Autocomplete support it).
    def dispatch_paste
      slot = focus.current
      return nil unless slot && respond_to?(slot, true)

      component = send(slot)
      return nil unless component.respond_to?(:handle_paste)

      result = component.handle_paste(event)
      return nil if result.nil?

      dispatch_component_result(slot, result)
      response
    end

    # Mouse event dispatcher: command palette (if open) wins, then sidebar clicks
    # (route rows navigate directly), then named layout panes/components.
    def dispatch_mouse
      return dispatch_command_palette_mouse if command_palette_open?

      sidebar_response = dispatch_sidebar_mouse
      return sidebar_response if sidebar_response

      dispatch_component_mouse
    end

    # Renders a body or template wrapped in the controller's layout. Out-of-band escape sequences
    # registered while rendering (e.g. image transmissions) are collected by the Runtime around the
    # whole dispatch and attached to the response.
    def render(body = "", **assigns)
      body = view_body(default_template_name(body), **assigns) if body.is_a?(Symbol)
      @response = Response.render(render_with_layout(body))
    end

    def render_view(view_class, **assigns)
      @response = Response.render(render_with_layout(view_class.new(**template_assigns(assigns))))
    end

    # Renders a template from `app/views` by name, applying the controller's layout. *name* is the
    # template path (e.g., "home/show") and additional keyword *assigns* are forwarded to the view.
    def render_template(name, **assigns)
      @response = Response.render(render_with_layout(template_body(name, **assigns)))
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

    # Opens the theme picker (a CommandPalette populated with the registered themes) and renders.
    def open_theme_palette
      session[:command_palette] = command_palette_state(:themes)
      focus.push_scope([:command_palette], origin: :command_palette)
      render_default_action
    end

    # Navigates to the screen registered under *name* in config/routes.rb, passing
    # *params* through to the target controller (e.g. `navigate :project, id: project.id`).
    def navigate(name, **params)
      @response = Response.navigate(name, **params)
    end

    # Exits the application — sets a quit response that terminates the event loop.
    def quit
      @response = Response.quit
    end

    private

    attr_reader :response
  end
end
