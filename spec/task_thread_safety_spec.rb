# frozen_string_literal: true

require "stringio"

RSpec.describe "task thread safety" do
  let(:application) { Charming::Application.new }
  let(:queue) { Thread::Queue.new }

  def build_controller(&action_block)
    Class.new(Charming::Controller) do
      define_method(:show, &action_block)
    end
  end

  describe "run_task with: data" do
    it "passes with: values to the block through the context" do
      application.task_executor = Charming::Tasks::InlineExecutor.new(queue)
      controller_class = build_controller do
        run_task(:fetch, with: {query: "ruby"}) { |ctx| ctx[:query] }
        render "queued"
      end

      controller_class.new(application: application).dispatch(:show)

      event = queue.pop(true)
      expect(event).to eq(Charming::Events::TaskEvent.new(name: :fetch, value: "ruby"))
    end

    it "freezes with: values so mutation inside the task raises FrozenError" do
      application.task_executor = Charming::Tasks::InlineExecutor.new(queue)
      query = +"ruby"
      tags = ["tui"]
      controller_class = Class.new(Charming::Controller) do
        define_method(:show) do
          run_task(:fetch, with: {query: query, tags: tags}) do |ctx|
            ctx[:tags] << "cli"
            ctx[:query] << "3"
          end
          render "queued"
        end
      end

      controller_class.new(application: application).dispatch(:show)

      event = queue.pop(true)
      expect(event.error).to be_a(FrozenError)
    end

    it "leaves the caller's original with: values unfrozen" do
      application.task_executor = Charming::Tasks::InlineExecutor.new(queue)
      tags = ["tui"]
      controller_class = Class.new(Charming::Controller) do
        define_method(:show) do
          run_task(:fetch, with: {tags: tags}) { |ctx| ctx[:tags].length }
          render "queued"
        end
      end

      controller_class.new(application: application).dispatch(:show)
      queue.pop(true)

      expect(tags).not_to be_frozen
      tags << "cli"
      expect(tags).to eq(["tui", "cli"])
    end

    it "reports progress through the context" do
      application.task_executor = Charming::Tasks::InlineExecutor.new(queue)
      controller_class = build_controller do
        run_task(:import) do |ctx|
          ctx.report(1, of: 2, message: "halfway")
          :done
        end
        render "queued"
      end

      controller_class.new(application: application).dispatch(:show)

      progress = queue.pop(true)
      completion = queue.pop(true)
      expect(progress).to be_a(Charming::Events::TaskProgressEvent)
      expect(progress.current).to eq(1)
      expect(progress.message).to eq("halfway")
      expect(completion.value).to eq(:done)
    end
  end

  describe "cross-thread access guard" do
    require "timeout"

    def pop_with_timeout
      Timeout.timeout(2) { queue.pop }
    end

    def with_threaded_executor
      application.task_executor = Charming::Tasks::ThreadedExecutor.new(queue)
      yield
    ensure
      application.task_executor&.shutdown
    end

    it "captures CrossThreadAccess when a task block renders off the loop thread" do
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch) { render "from task" }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_a(Charming::CrossThreadAccess)
        expect(event.error.message).to match(/render.*loop thread.*on_task/m)
      end
    end

    it "captures CrossThreadAccess when a task block writes the session" do
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch) { session[:from_task] = 1 }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_a(Charming::CrossThreadAccess)
        expect(event.error.message).to match(/session/)
      end
    end

    it "captures CrossThreadAccess when a task block navigates" do
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch) { navigate :elsewhere }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_a(Charming::CrossThreadAccess)
        expect(event.error.message).to match(/navigate/)
      end
    end

    it "captures CrossThreadAccess when a task block touches focus" do
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch) { focus.current }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_a(Charming::CrossThreadAccess)
        expect(event.error.message).to match(/focus/)
      end
    end

    it "logs a warning instead of raising in production" do
      Charming.env = "production"
      log = StringIO.new
      application.logger = Logger.new(log)
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch) { focus.current }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_nil
        expect(log.string).to match(/task thread called.*focus/)
      end
    ensure
      Charming.env = nil
    end

    it "runs a pure data-in/data-out task with zero warnings" do
      Charming.env = "production"
      log = StringIO.new
      application.logger = Logger.new(log)
      controller_class = Class.new(Charming::Controller) do
        def show
          run_task(:fetch, with: {query: "ruby"}) { |ctx| ctx[:query].upcase }
          render "queued"
        end
      end

      with_threaded_executor do
        controller_class.new(application: application).dispatch(:show)
        event = pop_with_timeout
        expect(event.error).to be_nil
        expect(event.value).to eq("RUBY")
        expect(log.string).to be_empty
      end
    ensure
      Charming.env = nil
    end

    it "runs progress handlers on the loop thread, never the executor thread" do
      task_thread = nil
      handler_thread = nil
      controller_class = Class.new(Charming::Controller) do
        on_task_progress :fetch, action: :progressed

        define_method(:show) do
          run_task(:fetch) do |ctx|
            task_thread = Thread.current
            ctx.report(1, of: 1)
            :done
          end
          render "queued"
        end

        define_method(:progressed) do
          handler_thread = Thread.current
          render "progress"
        end
      end

      with_threaded_executor do
        controller = controller_class.new(application: application)
        controller.dispatch(:show)
        progress_event = pop_with_timeout
        controller.dispatch_task_progress(progress_event)

        expect(handler_thread).not_to be_nil
        expect(task_thread).not_to be_nil
        expect(handler_thread).not_to equal(task_thread)
        expect(handler_thread).to equal(Thread.current)
      end
    end
  end
end
