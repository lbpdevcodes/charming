# frozen_string_literal: true

RSpec.describe Charming::View do
  it "exposes keyword assigns as reader methods" do
    view = Class.new(described_class) do
      def render
        "Hello #{name}"
      end
    end

    expect(view.new(name: "Ruby").render).to eq("Hello Ruby")
  end

  it "does not override existing private helper methods with assigns" do
    view = Class.new(described_class) do
      def render
        style.foreground(:cyan).render("Hello")
      end
    end

    expect(view.new(style: "ignored").render).to eq("\e[36mHello\e[0m")
  end

  it "answers respond_to? for assign names" do
    view = Class.new(described_class).new(name: "Ruby")

    expect(view.respond_to?(:name)).to be true
    expect(view.respond_to?(:missing_assign)).to be false
  end

  it "renders text with optional styles" do
    view = Class.new(described_class) do
      def render
        text "Hello", style: style.bold
      end
    end

    expect(view.new.render).to eq("\e[1mHello\e[0m")
  end

  it "renders boxes from explicit content" do
    view = Class.new(described_class) do
      def render
        box "Hi", style: style.border(:normal)
      end
    end

    expect(view.new.render).to eq("+--+\n|Hi|\n+--+")
  end

  it "captures text helper calls inside boxes" do
    view = Class.new(described_class) do
      def render
        box(style: style.border(:normal)) do
          text "A"
          text "B"
        end
      end
    end

    expect(view.new.render).to eq("+-+\n|A|\n|B|\n+-+")
  end

  it "composes rows and columns" do
    view = Class.new(described_class) do
      def render
        column(row("A", "B", gap: 1), "C", gap: 1)
      end
    end

    # Columns pad narrower lines to the widest block, keeping the result rectangular.
    expect(view.new.render).to eq("A B\n\nC  ")
  end

  it "renders components" do
    component = Class.new(Charming::Component) do
      def render
        "Hello #{name}"
      end
    end
    view = Class.new(described_class) do
      define_method(:render) do
        render_component component.new(name: "Ruby")
      end
    end

    expect(view.new.render).to eq("Hello Ruby")
  end

  it "renders partials" do
    partial = Class.new(described_class) do
      def render
        "Partial #{name}"
      end
    end
    view = Class.new(described_class) do
      define_method(:render) do
        render_partial partial.new(name: "Ruby")
      end
    end

    expect(view.new.render).to eq("Partial Ruby")
  end

  describe "#focused?" do
    let(:controller_double) do
      Class.new do
        def initialize(slot) = @slot = slot
        def focused?(slot) = slot == @slot
      end
    end

    it "delegates to the controller assign when one is passed" do
      view = Class.new(described_class) do
        def render
          focused?(:input) ? "input!" : "other"
        end
      end

      expect(view.new(controller: controller_double.new(:input)).render).to eq("input!")
      expect(view.new(controller: controller_double.new(:other)).render).to eq("other")
    end

    it "delegates to focus_controller for sub-components that aren't a layout" do
      view = Class.new(described_class) do
        def render
          focused?(:input) ? "yes" : "no"
        end
      end

      expect(view.new(focus_controller: controller_double.new(:input)).render).to eq("yes")
    end

    it "returns false when no controller assign is present" do
      view = Class.new(described_class) do
        def render
          focused?(:anything).to_s
        end
      end

      expect(view.new.render).to eq("false")
    end
  end

  it "yields layout content" do
    layout = Class.new(described_class) do
      def render
        "Layout: #{yield_content}"
      end
    end

    expect(layout.new(content: "Body").render).to eq("Layout: Body")
  end
end
