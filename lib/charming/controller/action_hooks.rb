# frozen_string_literal: true

module Charming
  class Controller
    # ActionHooks provides Rails-style before/after/around action hooks and rescue_from.
    # Class-level DSL: before_action, after_action, around_action, rescue_from.
    # Hook arrays are inherited by subclasses via dup.
    module ActionHooks
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      module ClassMethods
        # Registers a before hook that runs before the given *actions* (or all actions when
        # *only:* is omitted). *except:* excludes specific actions.
        def before_action(method_name, only: nil, except: nil)
          action_hooks << {type: :before, method: method_name, only: normalize_filter(only), except: normalize_filter(except)}
        end

        # Registers an after hook. Runs after the action even if the action rendered early.
        def after_action(method_name, only: nil, except: nil)
          action_hooks << {type: :after, method: method_name, only: normalize_filter(only), except: normalize_filter(except)}
        end

        # Registers an around hook. The hook method must yield to invoke the action.
        def around_action(method_name, only: nil, except: nil)
          action_hooks << {type: :around, method: method_name, only: normalize_filter(only), except: normalize_filter(except)}
        end

        # Registers an exception handler. When an action raises an exception matching *klass*
        # (or any of *classes*), the controller calls *with:* instead of propagating.
        def rescue_from(*classes, with:)
          rescue_handlers << {classes: classes.flatten, with: with}
        end

        # All registered hooks, inherited from superclass.
        def action_hooks
          @action_hooks ||= superclass.respond_to?(:action_hooks) ? superclass.action_hooks.dup : []
        end

        # All registered rescue handlers, inherited from superclass.
        def rescue_handlers
          @rescue_handlers ||= superclass.respond_to?(:rescue_handlers) ? superclass.rescue_handlers.dup : []
        end

        private

        def normalize_filter(value)
          return nil if value.nil?

          Array(value).map(&:to_sym)
        end
      end

      module InstanceMethods
        private

        # Wraps an action call in the full before/around/after hook chain and rescue handlers.
        # Replaces the plain `public_send(action)` in Controller#dispatch. Tracks the running
        # action so the DoubleRenderError message can name it.
        def run_action_with_hooks(action)
          previous, @current_action = @current_action, action
          run_with_rescue(action) { run_around_hooks(action) { run_action(action) } }
        ensure
          @current_action = previous
        end

        def run_action(action)
          run_before_hooks(action)
          public_send(action)
          run_after_hooks(action)
        end

        def run_before_hooks(action)
          hooks_for(action, :before).each { |hook| send(hook[:method]) }
        end

        def run_after_hooks(action)
          hooks_for(action, :after).each { |hook| send(hook[:method]) }
        end

        def run_around_hooks(action, &block)
          around = hooks_for(action, :around)
          wrap_around(around, 0, &block)
        end

        def wrap_around(hooks, index, &block)
          return yield if index >= hooks.length

          send(hooks[index][:method]) { wrap_around(hooks, index + 1, &block) }
        end

        def run_with_rescue(action)
          yield
        rescue => e
          handler = rescue_handler_for(e)
          raise unless handler

          send(handler[:with], e)
          render_default_action unless response
        end

        # Finds the handler whose rescued class is most specific for *exception* (closest in its
        # ancestor chain). Ties go to the last-registered handler. Note: this deliberately differs
        # from Rails, where declaration order alone decides — specificity is less surprising.
        def rescue_handler_for(exception)
          ancestors = exception.class.ancestors
          best = self.class.rescue_handlers.reverse.filter_map { |handler|
            specificity = handler[:classes].filter_map { |klass| ancestors.index(klass) }.min
            [specificity, handler] if specificity
          }.min_by(&:first)
          best&.last
        end

        def hooks_for(action, type)
          self.class.action_hooks.select do |hook|
            next false unless hook[:type] == type
            next false if hook[:only] && !hook[:only].include?(action.to_sym)
            next false if hook[:except]&.include?(action.to_sym)

            true
          end
        end
      end
    end
  end
end
