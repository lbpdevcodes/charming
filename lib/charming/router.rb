# frozen_string_literal: true

require "uri"

module Charming
  # Router manages an application's route table and provides a Rails-inspired DSL for defining routes.
  # Each route maps a URL path to a controller, action (implicitly :show), and title (for sidebar display).
  class Router
    # Route is a Data object holding a route's path template, target controller/action, title, and resolved params.
    Route = Data.define(:path, :controller_class, :action, :title, :params) do
      def with_params(params)
        self.class.new(
          path: path,
          controller_class: controller_class,
          action: action,
          title: title,
          params: params
        )
      end
    end

    DynamicRoute = Data.define(:route, :pattern, :param_names)

    # Initializes a new router with an optional namespace prefix for controller constant lookups.
    def initialize(namespace: nil)
      @namespace = namespace
      @routes = {}
      @dynamic_routes = []
    end

    # Evaluates a block in the context of this Router instance using instance_eval, allowing DSL calls like screen and root to register routes.
    # This is how `routes.draw { screen "/", to: "HomeController", title: "Home" }` works.
    def draw(&)
      instance_eval(&)
    end

    # Registers the home screen at "/" with a given title. Shorthand for `screen path, to: target`.
    # Example: `root "HomeController"` maps `/` → HomeController#show with title "Home".
    def root(target, title: "Home")
      screen("/", to: target, title: title)
    end

    # Maps a URL path to a controller and action (e.g. "HomeController" for HomeController#show).
    # Builds a Route object from the path, resolved controller constant, parsed action, and an optional or derived title.
    def screen(path, to:, title: nil)
      controller_name, action = to.split("#", 2)
      route = Route.new(
        path: path,
        controller_class: constantize(controller_constant_name(controller_name)),
        action: (action || "show").to_sym,
        title: title || derive_title(path),
        params: {}
      )
      @routes[path] = route
      @dynamic_routes.reject! { |dynamic_route| dynamic_route.route.path == path }
      @dynamic_routes << compile_dynamic_route(route) if dynamic_path?(path)
    end

    # Resolves a route by path from the router's table. Exact routes win over dynamic routes.
    # Raises KeyError if no route matches.
    # Used at runtime to look up the controller class and action for incoming requests.
    def resolve(path = "/")
      @routes[path] || resolve_dynamic(path) || raise(KeyError, "key not found: #{path.inspect}")
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

    def dynamic_path?(path)
      path.split("/").any? { |segment| segment.start_with?(":") && segment.length > 1 }
    end

    def compile_dynamic_route(route)
      param_names = []
      segments = route.path.split("/", -1).map do |segment|
        if segment.start_with?(":") && segment.length > 1
          param_names << segment.delete_prefix(":").to_sym
          "([^/]+)"
        else
          Regexp.escape(segment)
        end
      end

      DynamicRoute.new(route: route, pattern: /\A#{segments.join("/")}\z/, param_names: param_names)
    end

    def resolve_dynamic(path)
      @dynamic_routes.each do |dynamic_route|
        match = dynamic_route.pattern.match(path)
        return dynamic_route.route.with_params(extract_params(dynamic_route.param_names, match.captures)) if match
      end

      nil
    end

    def extract_params(names, values)
      names.zip(values).to_h do |name, value|
        [name, URI.decode_www_form_component(value)]
      end
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

    # Derives a human-readable title from a URL path by stripping the leading slash,
    # splitting on underscores/hyphens/slashes, capitalizing each segment, and joining with spaces.
    # Examples: "/projects" → "Projects", "/projects/list" → "Projects List".
    def derive_title(path)
      return "Home" if path == "/"

      path.delete_prefix("/").split(%r{[_\-/]}).map(&:capitalize).join(" ")
    end
  end
end
