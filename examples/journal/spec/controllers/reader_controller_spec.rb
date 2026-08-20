# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"

RSpec.describe Journal::ReaderController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }
  let(:entry) { Journal::Entry.create!(title: "A walk", mood: "good", body: "It was **lovely**.") }

  def controller_for(event = nil)
    route = app.routes.resolve(:entry, id: entry.id)
    described_class.new(application: app, route: route, params: route.params, event: event)
  end

  it "renders the markdown body with breadcrumbs" do
    response = controller_for.dispatch(:show)
    expect(response).to render_text("Journal › A walk")
    expect(response).to render_text("It was")
    expect(response).to render_text("😄 good")
  end

  it "navigates to the edit screen on e" do
    controller_for.dispatch(:show)
    response = controller_for(key_event("e")).dispatch_key
    expect(response).to navigate_to(:edit_entry, id: entry.id)
  end

  it "shows a friendly message for unknown ids" do
    route = app.routes.resolve(:entry, id: 999999)
    response = described_class.new(application: app, route: route, params: route.params).dispatch(:show)
    expect(response).to render_text("Entry not found")
  end

  it "deletes via the confirm modal and returns to the list" do
    controller_for.dispatch(:show)
    controller_for(key_event("d")).dispatch_key
    response = controller_for(key_event("y")).dispatch_key

    expect(Journal::Entry.exists?(entry.id)).to be false
    expect(response).to navigate_to(:root)
  end
end
