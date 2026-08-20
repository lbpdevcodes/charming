# frozen_string_literal: true

module Charming
  module Tasks
    # Context is the object a task block receives as its argument. It carries the
    # task's inputs (the `with:` hash given to `run_task`, deep-frozen at submit time)
    # and the progress reporter:
    #
    #   run_task(:search, with: {query: query.value}) do |ctx|
    #     results = Api.search(ctx[:query])
    #     ctx.report(1, of: 1)
    #     results
    #   end
    #
    # Task blocks receive data in via `with:` and return data out as the block value.
    # They touch nothing else: the `on_task` handler on the loop thread is the only
    # place task results become state.
    class Context
      def initialize(data, progress)
        @data = data
        @progress = progress
      end

      # Returns the input value for *key* from the `with:` hash.
      def [](key)
        @data[key]
      end

      # Reports progress to the matching `on_task_progress` handler on the loop thread.
      def report(current, of: nil, message: nil)
        @progress.report(current, of: of, message: message)
      end
    end
  end
end
