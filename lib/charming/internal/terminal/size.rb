# frozen_string_literal: true

module Charming
  module Internal
    module Terminal
      # Size detects terminal dimensions without tty-screen: IO#winsize on the first
      # reporting IO (a TTY), then ENV["COLUMNS"]/ENV["LINES"], then the 80x24 default.
      module Size
        DEFAULT_SIZE = [80, 24].freeze

        module_function

        # Returns [width, height] for the first of *ios* that reports a winsize,
        # falling back to the environment and then the default.
        def measure(*ios, env: ENV)
          ios.each do |io|
            size = winsize(io)
            return size if size
          end
          env_size(env) || DEFAULT_SIZE
        end

        # IO#winsize reports [rows, columns]; size is [width, height]. Nil for IOs
        # without a size (StringIO, pipes, closed streams).
        def winsize(io)
          return nil unless io.respond_to?(:winsize)

          rows, columns = io.winsize
          return nil if rows.to_i.zero? || columns.to_i.zero?

          [columns, rows]
        rescue SystemCallError, IOError
          nil
        end

        # The COLUMNS/LINES environment size, or nil when either is unset or zero.
        def env_size(env)
          columns = env["COLUMNS"].to_i
          lines = env["LINES"].to_i
          return nil if columns.zero? || lines.zero?

          [columns, lines]
        end
      end
    end
  end
end
