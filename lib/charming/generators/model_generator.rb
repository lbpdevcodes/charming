# frozen_string_literal: true

module Charming
  module Generators
    # ModelGenerator implements `charming generate model NAME [name:type ...]`. Writes an
    # ActiveRecord model class, a `Create<Table>` migration (with one column per supplied
    # field), and a baseline spec. Requires the app to have been generated with
    # `--database sqlite3`.
    class ModelGenerator < AppFileGenerator
      # A single model field: column *name* and ActiveRecord *type* (e.g., "string").
      Field = Data.define(:name, :type)

      # The set of ActiveRecord column types accepted on the command line.
      VALID_TYPES = %w[string text integer float decimal boolean date datetime time].freeze

      # *name* is the resource name. *args* is the list of `name:type` field specifications.
      def initialize(name, args, out:, destination:, force: false)
        super
        @fields = args.map { |arg| parse_field(arg) }
      end

      # Validates that the app is database-configured, then writes the model, migration,
      # and spec files.
      def generate
        raise Error, "Database support is not configured. Generate the app with --database sqlite3 first." unless database_configured?

        create_file(model_path, model)
        create_file(migration_path, migration)
        create_file(spec_path, spec)
      end

      private

      # The list of parsed Field entries supplied on the command line.
      attr_reader :fields

      # No file-name suffix; ModelGenerator writes files to explicit paths.
      def suffix
        nil
      end

      # Path to the generated `app/models/<name>.rb` file.
      def model_path
        File.join("app", "models", "#{name.snake_name}.rb")
      end

      # Path to the generated `db/migrate/<timestamp>_create_<table>.rb` file.
      def migration_path
        File.join("db", "migrate", "#{timestamp}_create_#{table_name}.rb")
      end

      # Path to the generated `spec/models/<name>_spec.rb` file.
      def spec_path
        File.join("spec", "models", "#{name.snake_name}_spec.rb")
      end

      # The full source of the generated ActiveRecord model class.
      def model
        render_template("model/model.rb.template",
          app_class: app_name.class_name,
          model_class: name.class_name)
      end

      # The full source of the generated migration, with one `t.<type> :<name>` line per field.
      def migration
        render_template("model/migration.rb.template",
          table_class: table_class_name,
          table_name: table_name,
          field_lines: field_lines)
      end

      # The full source of the generated model spec (asserts the model inherits from
      # `ApplicationRecord`).
      def spec
        render_template("model/spec.rb.template",
          app_snake: app_name.snake_name,
          app_class: app_name.class_name,
          model_class: name.class_name)
      end

      # Renders one `t.<type> :<name>` line per field, joined together.
      def field_lines
        fields.map { |field|
          "      t.#{field.type} :#{field.name}\n"
        }.join
      end

      # Parses a single `name:type` argument. Raises Error on invalid names or unsupported types.
      def parse_field(value)
        field_name, type = value.split(":", 2)
        raise Error, "Invalid field: #{value.inspect}" unless field_name && type
        raise Error, "Invalid field name: #{field_name.inspect}" unless Name::VALID_NAME.match?(field_name)
        raise Error, "Unsupported field type: #{type.inspect}" unless VALID_TYPES.include?(type)

        Field.new(name: field_name, type: type)
      end

      # True when `config/database.rb` and `app/models/application_record.rb` both exist.
      def database_configured?
        File.exist?(File.join(destination, "config", "database.rb")) &&
          File.exist?(File.join(destination, "app", "models", "application_record.rb"))
      end

      # The pluralized table name (e.g., "user" → "users", "category" → "categories").
      def table_name
        Internal::Inflections.pluralize(name.snake_name)
      end

      # The CamelCase migration class name (e.g., "users" → "Users").
      def table_class_name
        Internal::Inflections.camelize(table_name)
      end

      # A migration timestamp in ActiveRecord's filename format, bumped past any
      # existing migration's version so two generators run in the same second
      # can't produce colliding versions.
      def timestamp
        MigrationTimestamp.next(File.join(destination, "db", "migrate"))
      end
    end
  end
end
