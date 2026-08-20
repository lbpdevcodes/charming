# frozen_string_literal: true

RSpec.describe "DoubleRenderError" do
  let(:application) { Charming::Application.new }

  it "raises when an action renders and then navigates" do
    controller_class = Class.new(Charming::Controller) do
      def self.name
        "DoubleRenderSpecController"
      end

      def show
        render "first"
        navigate :elsewhere
      end
    end

    expect { controller_class.new(application: application).dispatch(:show) }
      .to raise_error(Charming::DoubleRenderError, /show.*render.*navigate.*:elsewhere/im)
  end

  it "raises when an action navigates and then quits" do
    controller_class = Class.new(Charming::Controller) do
      def show
        navigate :elsewhere
        quit
      end
    end

    expect { controller_class.new(application: application).dispatch(:show) }
      .to raise_error(Charming::DoubleRenderError, /navigate.*:elsewhere.*quit/im)
  end

  it "raises when an action renders a view after rendering a string" do
    view_class = Class.new(Charming::View)
    controller_class = Class.new(Charming::Controller) do
      define_method(:show) do
        render "first"
        render_view view_class
      end
    end

    expect { controller_class.new(application: application).dispatch(:show) }
      .to raise_error(Charming::DoubleRenderError, /render.*render_view/im)
  end

  it "keeps the response of a palette command that renders" do
    controller_class = Class.new(Charming::Controller) do
      include Charming::Shell::Palette

      command("Render") { render "Command output" }

      def show
        render "Show body"
      end
    end

    instance = controller_class.new(application: application)
    instance.open_command_palette
    response = instance.dispatch_key(Charming::Events::KeyEvent.new(key: :enter))

    expect(response.body).to eq("Command output")
  end
end
