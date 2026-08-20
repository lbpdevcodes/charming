# frozen_string_literal: true

RSpec.describe "Sidebar mouse navigation" do
  let(:app) { SidebarMouseSpecApp.new }
  let(:rect) { Charming::Layout::Rect.new(x: 0, y: 0, width: 22, height: 24) }
  let(:inner_rect) { Charming::Layout::Rect.new(x: 2, y: 2, width: 18, height: 20) }

  before do
    controller_class = Class.new(Charming::Controller) do
      focus_ring :sidebar, :content

      def show = render("home")

      def settings = render("settings")
    end
    stub_const("SidebarMouseSpecController", controller_class)
    app_class = Class.new(Charming::Application)
    stub_const("SidebarMouseSpecApp", app_class)
    app_class.routes do
      root "sidebar_mouse_spec#show"
      screen :settings, "sidebar_mouse_spec#settings", title: "Settings"
    end
  end

  def click(x, y)
    Charming::Events::MouseEvent.new(button: 0, x: x, y: y)
  end

  def controller_for(event)
    SidebarMouseSpecController.new(application: app, event: event)
  end

  def register_sidebar_target
    controller_for(nil).register_mouse_targets([
      {name: :sidebar, rect: rect, inner_rect: inner_rect}
    ])
  end

  it "navigates to the clicked route row" do
    register_sidebar_target
    # nav rows start at inner_rect.y + sidebar_nav_offset = 2 + 2 = 4; row 1 = Settings
    response = controller_for(click(3, 5)).dispatch_mouse

    expect(response.navigate?).to be true
    expect(response.name).to eq(:settings)
  end

  it "focuses the sidebar when clicking non-row sidebar space" do
    register_sidebar_target
    controller_for(click(3, 2)).dispatch_mouse # the title row

    expect(controller_for(nil).sidebar_focused?).to be true
  end

  it "ignores clicks outside the sidebar" do
    register_sidebar_target
    response = controller_for(click(50, 5)).dispatch_mouse
    expect(response).to be_nil
  end

  it "updates the sidebar index to the clicked row" do
    register_sidebar_target
    controller_for(click(3, 5)).dispatch_mouse
    expect(app.session[:sidebar_index]).to eq(1)
  end
end
