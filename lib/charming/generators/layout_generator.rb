# frozen_string_literal: true

module Charming
  module Generators
    # LayoutGenerator implements `charming generate layout [--style sidebar]`. It restores
    # the full app chrome that `charming new` no longer ships by default: the sidebar
    # layout, the sidebar/content focus ring, the command palette bindings, and the
    # built-in theme registration. Safe to re-run: existing chrome is left untouched.
    class LayoutGenerator < AppFileGenerator
      STYLES = %w[sidebar].freeze
      USAGE = "Usage: charming generate layout [--style sidebar]"

      # *name* is unused (the CLI passes "application"); *args* may carry `--style STYLE`.
      def initialize(name, args, out:, destination:, force: false)
        @style = extract_style(args)
        super
        raise Error, USAGE if args.any?
      end

      # Writes the styled application layout, then inserts the controller chrome and the
      # theme registration into the existing app files.
      def generate
        write_layout
        insert_controller_chrome
        insert_theme_registration
      end

      private

      # The layout style name (currently always "sidebar").
      attr_reader :style

      # The file-name suffix used by `app_path` (only used by the parent class).
      def suffix
        "layout"
      end

      # Extracts the optional `--style` argument from *args*, removing it in place.
      # Defaults to the first supported style when absent.
      def extract_style(args)
        inline = args.find { |arg| arg.start_with?("--style=") }
        return validate_style(args.delete(inline).split("=", 2).last) if inline

        index = args.index("--style")
        return STYLES.first unless index

        args.delete_at(index)
        validate_style(args.delete_at(index) || raise(Error, USAGE))
      end

      # Validates that *style* is a supported layout style.
      def validate_style(style)
        return style if STYLES.include?(style)

        raise Error, "Unknown layout style: #{style.inspect} (available: #{STYLES.join(", ")})"
      end

      # Replaces the application layout with the styled one. Creates it when missing,
      # no-ops when already styled, and refuses to clobber local edits unless forced.
      def write_layout
        return create_file(layout_relative_path, styled_layout) unless File.exist?(layout_path)
        return out.puts("identical #{layout_relative_path}") if current_layout == styled_layout
        raise Error, "#{layout_relative_path} has local changes; re-run with --force to overwrite" unless replaceable_layout?

        overwrite_layout
      end

      # True when the current layout may be replaced: forced, or still the generated bare layout.
      def replaceable_layout?
        force? || current_layout == bare_layout
      end

      def overwrite_layout
        File.write(layout_path, styled_layout)
        out.puts "overwrite #{layout_relative_path}"
      end

      def current_layout
        File.read(layout_path)
      end

      # The rendered layout for the requested style.
      def styled_layout
        @styled_layout ||= render_template("layout/#{style}/application_layout.rb.template",
          app_class: app_name.class_name,
          app_name: app_name.class_name)
      end

      # The bare layout `charming new` generates, used to recognize unmodified apps.
      def bare_layout
        render_template("app/layout.template", app_class: app_name.class_name)
      end

      # Inserts the focus ring, palette key binding, and palette commands into
      # `ApplicationController`, idempotently.
      def insert_controller_chrome
        insert_before_end(application_controller_path, controller_chrome, "chrome", "  end")
      end

      def controller_chrome
        class_body_block(<<~RUBY)
          include Charming::Shell::Sidebar
          include Charming::Shell::Palette

          focus_ring :sidebar, :content

          key "ctrl+p", :open_command_palette, scope: :global

          command "Home" do
            navigate :root
          end

          command "Theme", :open_theme_palette
          command "Close palette", :close_command_palette
          command "Quit app", :quit
        RUBY
      end

      # Inserts the built-in theme registration into the app's Application class, idempotently.
      def insert_theme_registration
        insert_before_end(application_config_path, theme_registration, "themes", "  end")
      end

      def theme_registration
        class_body_block(<<~RUBY)
          Charming::UI::Theme.built_in_names.each do |theme_name|
            theme theme_name.to_sym, built_in: theme_name
          end

          default_theme :phosphor
        RUBY
      end

      # Indents *source* to class-body depth and prefixes a blank separator line, so the
      # inserted block reads naturally after the existing declarations.
      def class_body_block(source)
        body = source.gsub(/^/, "    ").gsub(/^ +$/, "").chomp
        "\n#{body}"
      end

      def layout_relative_path
        File.join("app", "views", "layouts", "application_layout.rb")
      end

      def layout_path
        File.join(destination, layout_relative_path)
      end

      def application_controller_path
        File.join(destination, "app", "controllers", "application_controller.rb")
      end

      def application_config_path
        File.join(destination, "lib", app_name.snake_name, "application.rb")
      end
    end
  end
end
