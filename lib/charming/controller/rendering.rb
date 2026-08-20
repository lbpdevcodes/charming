# frozen_string_literal: true

module Charming
  class Controller
    # Rendering pipeline mixed into Controller. Resolves view classes, template paths, layouts,
    # and assigns. Most helpers are private — only `render`/`render_view`/`render_template` are
    # part of the public controller API and live in `controller.rb` itself.
    module Rendering
      private

      # Returns the string body for *body* — if it responds to `render` (e.g., a View or Component),
      # delegates to that; otherwise calls `to_s`.
      def render_body(body)
        body.respond_to?(:render) ? body.render.to_s : body.to_s
      end

      # Wraps *body* (a string) in the controller's configured layout, if any. When no layout is set
      # the body is returned as-is. Render artifacts from every view rendered (body first, layout
      # last) accumulate on the controller for the dispatch to commit.
      def render_with_layout(body)
        rendered = render_body(body)
        collect_render_artifacts(body)
        layout = self.class.layout
        return rendered unless layout

        layout_view = layout_body(layout, body, rendered)
        render_body(layout_view).tap { collect_render_artifacts(layout_view) }
      end

      # Accumulates the render artifacts *body* stashed during its render, if any. Strings
      # and template-less bodies carry none.
      def collect_render_artifacts(body)
        return unless body.respond_to?(:render_artifacts)

        dispatch_render_artifacts.concat(body.render_artifacts)
      end

      # The render artifacts accumulated during this dispatch, in render order.
      def dispatch_render_artifacts
        @dispatch_render_artifacts ||= []
      end

      # Builds the layout wrapper for *body* / *rendered* content. String/Symbol layouts are
      # resolved as templates; other values are treated as layout view classes.
      def layout_body(layout, body, rendered)
        assigns = layout_assigns(body, rendered)
        return template_body(layout, **assigns) if layout.is_a?(String) || layout.is_a?(Symbol)

        layout.new(**assigns)
      end

      # Returns a view object for *name* — a conventional view class when one exists under the
      # application namespace, otherwise a TemplateView rendered from `app/views`.
      def view_body(name, **assigns)
        view_class = conventional_view_class(name)
        return view_class.new(**template_assigns(assigns)) if view_class

        template_body(name, **assigns)
      end

      # Builds the assigns hash passed to layout view constructors: view's own assigns, plus
      # `content:`, `screen:`, `controller:`, and `theme:`.
      def layout_assigns(body, rendered)
        view_assigns(body).merge(content: rendered, screen: screen, controller: self, theme: theme)
      end

      # Returns the assigns hash from *body* (a View), or an empty hash when *body* doesn't expose them.
      def view_assigns(body)
        body.respond_to?(:layout_assigns) ? body.layout_assigns : {}
      end

      # Resolves a template by *name* and returns a TemplateView bound to the application's namespace.
      def template_body(name, **assigns)
        TemplateView.new(template: resolve_template(name), namespace: template_namespace, **template_assigns(assigns))
      end

      # Looks up the template file under `app/views` relative to the application root.
      def resolve_template(name)
        Templates.resolve(name, root: application.class.root)
      end

      # Returns the assigns hash passed to templates: `screen:`, `controller:`, `theme:` plus user *assigns*.
      def template_assigns(assigns)
        {screen: screen, controller: self, theme: theme}.merge(assigns)
      end

      # Returns the application namespace constant (e.g., `MyApp`) used for view-class lookup,
      # or nil when the application has no namespace.
      def template_namespace
        namespace_name = application.class.namespace
        return nil if namespace_name.to_s.empty?

        Object.const_get(namespace_name)
      end

      # Returns the conventional view class for *name* (e.g., `MyApp::Home::ShowView`) when defined
      # under the application namespace. Returns nil when no such class exists.
      def conventional_view_class(name)
        namespace = template_namespace
        return unless namespace

        constant_path = conventional_view_constant_path(name)
        constant_path.reduce(namespace) do |scope, constant_name|
          break unless scope.const_defined?(constant_name, false)

          scope.const_get(constant_name, false)
        end
      end

      # Builds the constant lookup path (array of strings) for a conventional view class from *name*.
      # Splits "home/show" → ["Home", "ShowView"].
      def conventional_view_constant_path(name)
        parts = name.to_s.split("/")
        action = parts.pop
        view_name = "#{Internal::Inflections.camelize(action.to_s)}View"

        parts.map { |part| Internal::Inflections.camelize(part) } + [view_name]
      end

      # Returns the default template path for a given *action* (e.g., "home/show" for HomeController#show).
      def default_template_name(action)
        "#{controller_template_path}/#{action}"
      end

      # Returns the underscored controller path (e.g., "home" for HomeController) used for view lookup.
      def controller_template_path
        controller_name = Internal::Inflections.demodulize(self.class.name).delete_suffix("Controller")
        Internal::Inflections.underscore(controller_name)
      end
    end
  end
end
