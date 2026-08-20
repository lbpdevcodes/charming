# frozen_string_literal: true

module Charming
  module Generators
    # ScreenGenerator implements `charming generate screen NAME`. Writes a complete vertical
    # slice for a new screen: a state class, a controller with a `show` action, a view,
    # matching spec files, and inserts a route into `config/routes.rb` and a command entry
    # into `ApplicationController` for the command palette.
    class ScreenGenerator < AppFileGenerator
      # *name* is the resource name. *args* is unused (raises Error when non-empty).
      def initialize(name, args, out:, destination:, force: false)
        super
        raise Error, "Usage: charming generate screen NAME" if args.any?
      end

      # Writes the state, controller, view, and three spec files, then inserts a route
      # and a command-palette entry.
      def generate
        create_file(state_path, state)
        create_file(controller_path, controller)
        create_file(view_path, view)
        create_file(spec_state_path, spec_state)
        create_file(spec_controller_path, spec_controller)
        create_file(spec_view_path, spec_view)
        insert_route
        insert_command
      end

      private

      # The file-name suffix used by `app_path` ("screen" — only used by the parent class).
      def suffix
        "screen"
      end

      # Path to the generated state class.
      def state_path
        File.join("app", "state", "#{name.snake_name}_state.rb")
      end

      # Path to the generated controller class.
      def controller_path
        File.join("app", "controllers", "#{name.snake_name}_controller.rb")
      end

      # Path to the generated `show` view.
      def view_path
        File.join("app", "views", name.snake_name, "show_view.rb")
      end

      # Path to the generated state spec.
      def spec_state_path
        File.join("spec", "state", "#{name.snake_name}_state_spec.rb")
      end

      # Path to the generated controller spec.
      def spec_controller_path
        File.join("spec", "controllers", "#{name.snake_name}_controller_spec.rb")
      end

      # Path to the generated view spec.
      def spec_view_path
        File.join("spec", "views", name.snake_name, "show_view_spec.rb")
      end

      # Absolute path to the app's `config/routes.rb`.
      def route_path
        File.join(destination, "config", "routes.rb")
      end

      # Absolute path to the app's `ApplicationController`.
      def application_controller_path
        File.join(destination, "app", "controllers", "application_controller.rb")
      end

      # The source of the generated state class.
      def state
        render_template("screen/state.rb.template",
          app_class: app_name.class_name,
          state_class: "#{name.class_name}State",
          title: name.class_name)
      end

      # The source of the generated controller class.
      def controller
        render_template("screen/controller.rb.template",
          app_class: app_name.class_name,
          controller_class: name.controller_class_name,
          controller_body: controller_body)
      end

      # The body of the controller: a `show` action and a private accessor for the state.
      def controller_body
        "    def show\n" \
          "      render :show,\n" \
          "        #{name.snake_name}: #{name.snake_name},\n" \
          "        palette: command_palette\n" \
          "    end\n" \
          "\n" \
          "    private\n" \
          "\n" \
          "    def #{name.snake_name}\n" \
          "      state(:#{name.snake_name}, #{name.class_name}State)\n" \
          "    end"
      end

      # The source of the generated view class.
      def view
        render_template("screen/view.rb.template",
          app_class: app_name.class_name,
          resource_module: name.class_name,
          screen_name: name.snake_name)
      end

      # The source of the generated state spec.
      def spec_state
        render_template("screen/spec_state.rb.template",
          app_snake: app_name.snake_name,
          app_class: app_name.class_name,
          state_class: "#{name.class_name}State",
          title: name.class_name)
      end

      # The source of the generated controller spec.
      def spec_controller
        render_template("screen/spec_controller.rb.template",
          app_snake: app_name.snake_name,
          app_class: app_name.class_name,
          controller_class: name.controller_class_name)
      end

      # The source of the generated view spec.
      def spec_view
        render_template("screen/spec_view.rb.template",
          app_snake: app_name.snake_name,
          app_class: app_name.class_name,
          resource_module: name.class_name,
          screen_name: name.snake_name,
          title: name.class_name)
      end

      # Inserts a `screen` route into `config/routes.rb`, idempotently.
      def insert_route
        route = %(  screen :#{name.snake_name}, "#{name.snake_name}#show", title: "#{name.class_name}")
        insert_before_end(route_path, route, "route", "end")
      end

      # Inserts a `command` block into `ApplicationController`, idempotently.
      def insert_command
        command = %(    command "#{name.class_name}" do
      navigate :#{name.snake_name}
    end)
        insert_before_end(application_controller_path, command, "command", "  end")
      end
    end
  end
end
