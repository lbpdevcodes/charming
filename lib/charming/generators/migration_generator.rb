# frozen_string_literal: true

module Charming
  module Generators
    # MigrationGenerator implements `charming generate migration NAME [field:type ...]`.
    # Follows Rails naming conventions:
    # - `create_<table>` generates a create_table migration (fields become columns)
    # - `add_<x>_to_<table>` generates add_column lines for the supplied fields
    # - `remove_<x>_from_<table>` generates remove_column lines
    # - anything else generates an empty `change` method to fill in
    class MigrationGenerator < AppFileGenerator
      # A single migration field: column *name* and ActiveRecord *type*.
      Field = Data.define(:name, :type)

      # The set of ActiveRecord column types accepted on the command line.
      VALID_TYPES = ModelGenerator::VALID_TYPES

      def initialize(name, args, out:, destination:, force: false)
        super
        @fields = args.map { |arg| parse_field(arg) }
      end

      # Validates database support, then writes the timestamped migration file.
      def generate
        raise Error, "Database support is not configured. Run `charming db:install sqlite3` first." unless database_configured?

        create_file(migration_path, migration)
      end

      private

      attr_reader :fields

      # No file-name suffix; MigrationGenerator writes to an explicit path.
      def suffix
        nil
      end

      # Path to the generated `db/migrate/<timestamp>_<name>.rb` file.
      def migration_path
        File.join("db", "migrate", "#{timestamp}_#{name.snake_name}.rb")
      end

      # The ActiveRecord migration API version stamped into generated migrations. Matches
      # the version used by the model generator's migration template.
      MIGRATION_VERSION = "8.1"

      # The full source of the generated migration, dispatching on the name convention.
      def migration
        <<~RUBY
          # frozen_string_literal: true

          class #{migration_class_name} < ActiveRecord::Migration[#{MIGRATION_VERSION}]
            def change
          #{change_body.chomp}
            end
          end
        RUBY
      end

      # The CamelCase migration class name derived from the snake_case migration name.
      def migration_class_name
        Internal::Inflections.camelize(name.snake_name)
      end

      # Builds the `change` method body based on the migration name convention.
      def change_body
        case name.snake_name
        when /\Acreate_(.+)\z/
          create_table_body(Regexp.last_match(1))
        when /\Aadd_.+_to_(.+)\z/
          column_lines(Regexp.last_match(1), :add_column)
        when /\Aremove_.+_from_(.+)\z/
          column_lines(Regexp.last_match(1), :remove_column)
        else
          "    # Add your migration steps here.\n"
        end
      end

      # Generates a `create_table` block with one column line per field plus timestamps.
      def create_table_body(table)
        field_lines = fields.map { |field| "      t.#{field.type} :#{field.name}\n" }.join
        "    create_table :#{table} do |t|\n#{field_lines}      t.timestamps\n    end\n"
      end

      # Generates one add_column/remove_column line per field for the given table.
      def column_lines(table, method)
        return "    # No fields given — add #{method} lines here.\n" if fields.empty?

        fields.map { |field| "    #{method} :#{table}, :#{field.name}, :#{field.type}\n" }.join
      end

      # Parses a single `name:type` argument. Raises Error on invalid names or unsupported types.
      def parse_field(value)
        field_name, type = value.split(":", 2)
        raise Error, "Invalid field: #{value.inspect}" unless field_name && type
        raise Error, "Invalid field name: #{field_name.inspect}" unless Name::VALID_NAME.match?(field_name)
        raise Error, "Unsupported field type: #{type.inspect}" unless VALID_TYPES.include?(type)

        Field.new(name: field_name, type: type)
      end

      # True when `config/database.rb` exists in the app.
      def database_configured?
        File.exist?(File.join(destination, "config", "database.rb"))
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
