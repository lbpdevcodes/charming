# frozen_string_literal: true

module Charming
  # Router manages an application's screen table and provides a Rails-inspired DSL for
  # defining screens. Each screen maps a symbolic name to a controller, an action
  # (implicitly :show), and a title (for sidebar display). Navigation passes params
  # directly — there are no URL path templates.
  class Router
    # Route is a Data object holding a screen's name, target controller/action, title,
    # and resolved params.
    Route = Data.define(:name, :controller_class, :action, :title, :params) do
      def with_params(params)
        self.class.new(
          name: name,
          controller_class: controller_class,
          action: action,
          title: title,
          params: params
        )
      end
    end

    # Initializes a new router with an optional namespace prefix for controller constant lookups.
    def initialize(namespace: nil)
      @namespace = namespace
      @routes = {}
    end

    # Evaluates a block in the context of this Router instance using instance_eval, allowing DSL
    # calls like screen and root to register routes.
    # This is how `routes.draw { root "home#show" }` works.
    def draw(&)
      instance_eval(&)
    end

    # Registers the home screen under the reserved name :root.
    # Example: `root "home#show"` maps :root → HomeController#show with title "Home".
    def root(target, title: "Home")
      screen(:root, target, title: title)
    end

    # Maps a symbolic *name* to a controller and action (e.g. "home#show" for
    # HomeController#show; the action defaults to :show). *title* defaults to a
    # humanized form of the name.
    def screen(name, target = nil, title: nil, to: nil)
      name = screen_name(name)
      target ||= to or raise ArgumentError, "screen :#{name} needs a target like \"home#show\""
      controller_name, action = target.split("#", 2)
      @routes[name] = Route.new(
        name: name,
        controller_class: constantize(controller_constant_name(controller_name)),
        action: (action || "show").to_sym,
        title: title || derive_title(name),
        params: {}
      )
    end

    # Resolves a screen by name, returning the route with *params* attached. Raises
    # KeyError listing the registered names when no screen matches. Used at runtime to
    # look up the controller class and action for navigation.
    def resolve(name = :root, params = {})
      @routes.fetch(name.to_sym) do
        raise KeyError, "unknown screen #{name.inspect} (registered screens: #{@routes.keys.map(&:inspect).join(", ")})"
      end.with_params(params)
    end

    # Returns all registered routes as Route objects, ordered by insertion.
    # Consumed by the application loop to populate the sidebar and by controllers for navigation context.
    def all
      @routes.values
    end

    private

    # The namespace prefix from initialization — used to scope controller constant lookups.
    # For example, namespace "Admin" means HomeController resolves as Admin::HomeController.
    attr_reader :namespace

    # Normalizes a screen name to a Symbol, rejecting legacy string URL paths with a
    # migration hint.
    def screen_name(name)
      return name if name.is_a?(Symbol)
      raise ArgumentError, string_path_hint(name, "screen") if name.is_a?(String) && name.start_with?("/")

      name.to_sym
    end

    # Looks up a constant by name in Object. Used to resolve controller strings from route definitions.
    def constantize(name)
      Internal::Inflections.constantize(name)
    end

    # Builds the full controller constant name, prepending the namespace if present.
    # For example: "home" with namespace "Admin" → "Admin::HomeController".
    def controller_constant_name(controller_name)
      name = "#{Internal::Inflections.camelize(controller_name)}Controller"
      @namespace.to_s.empty? ? name : "#{@namespace}::#{name}"
    end

    # Derives a human-readable title from a screen name by splitting on underscores and
    # hyphens, capitalizing each segment, and joining with spaces.
    # Example: :project_list → "Project List".
    def derive_title(name)
      name.to_s.split(/[_-]/).map(&:capitalize).join(" ")
    end

    # The error message for callers still passing string URL paths.
    def string_path_hint(path, dsl)
      suggestion = path.split("/")[1].to_s.delete_prefix(":")
      "String URL paths were removed. Register screens by name — `#{dsl} :#{suggestion}, ...` — " \
        "and navigate with `navigate :#{suggestion}`. See UPGRADING.md."
    end
  end
end
