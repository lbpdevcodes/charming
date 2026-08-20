# frozen_string_literal: true

require "charming/test_helper"

RSpec.describe "pure rendering" do
  include Charming::TestHelper

  let(:application) { Charming::Application.new }

  it "renders a view with screen_layout and no controller, returning artifacts" do
    view_class = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:left, width: 4, focus: true) { "L" }
            pane(:right, grow: 1, focus: true) { "R" }
          end
        end
      end
    end

    result = render_view(view_class, screen: Charming::Screen.new(width: 8, height: 1))

    expect(result[:frame]).to include("L")
    expect(result[:frame]).to include("R")
    expect(result[:focus_slots]).to eq(%i[left right])
    expect(result[:mouse_targets].map { |target| target[:name] }).to eq(%i[left right])
  end

  it "commits a rendered response's artifacts at dispatch exit" do
    view_class = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:list, width: 4, focus: true) { "L" }
          end
        end
      end
    end
    controller_class = Class.new(Charming::Controller) do
      focus_ring :list

      define_method(:show) do
        render view_class.new(screen: screen, controller: self)
      end
    end

    controller = controller_class.new(application: application)
    controller.dispatch(:show)

    expect(controller.focus.ring).to eq([:list])
    expect(controller.mouse_targets.map { |target| target[:name] }).to eq([:list])
  end

  it "commits nothing when a dispatch raises mid-render, leaving prior registrations live" do
    good_view = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:list, width: 4, focus: true) { "L" }
          end
        end
      end
    end
    bad_view = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:evil, width: 4, focus: true) { "E" }
          end
        end
        raise "boom"
      end
    end
    controller_class = Class.new(Charming::Controller) do
      focus_ring :list, :evil

      define_method(:show) { render good_view.new(screen: screen, controller: self) }
      define_method(:boom) { render bad_view.new(screen: screen, controller: self) }
    end

    controller = controller_class.new(application: application)
    controller.dispatch(:show)
    expect { controller.dispatch(:boom) }.to raise_error("boom")

    expect(controller.focus.ring).to eq([:list])
    expect(controller.mouse_targets.map { |target| target[:name] }).to eq([:list])
  end

  it "treats the last screen_layout as the focus source and concatenates mouse targets in render order" do
    view_class = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:first, width: 4, focus: true) { "F" }
          end
        end
        screen_layout do
          split :horizontal do
            pane(:second, width: 4, focus: true) { "S" }
          end
        end
      end
    end
    controller_class = Class.new(Charming::Controller) do
      focus_ring :first, :second

      define_method(:show) do
        render view_class.new(screen: screen, controller: self)
      end
    end

    controller = controller_class.new(application: application)
    controller.dispatch(:show)

    expect(controller.focus.ring).to eq([:second])
    expect(controller.mouse_targets.map { |target| target[:name] }).to eq(%i[first second])
  end
end
