# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"

RSpec.describe Journal::ComposeController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }
  let(:ctrl) { build_controller(described_class, app: app) }

  def type(string)
    string.chars.each { |char| press(ctrl, char) }
  end

  it "renders the new-entry form" do
    response = ctrl.dispatch(:show)
    expect(response).to render_text("New entry")
    expect(response).to render_text("Title")
    expect(response).to render_text("Mood")
  end

  it "creates an entry through the form" do
    ctrl.dispatch(:show)
    type("Hello")
    response = press(ctrl, "ctrl+s")

    entry = Journal::Entry.find_by(title: "Hello")
    expect(entry).not_to be_nil
    expect(entry.mood).to eq("good")
    expect(response).to navigate_to(:entry, id: entry.id)
  end

  it "keeps the form open with errors when the title is missing" do
    ctrl.dispatch(:show)
    response = press(ctrl, "ctrl+s")

    expect(Journal::Entry.count).to eq(0)
    expect(response).to render_text("is required")
  end

  it "pre-seeds the form when editing" do
    entry = Journal::Entry.create!(title: "Original", mood: "rough", body: "body text")
    route = app.routes.resolve(:edit_entry, id: entry.id)
    controller = described_class.new(application: app, route: route, params: route.params)
    response = controller.dispatch(:edit)

    expect(response).to render_text("Edit \"Original\"")
    expect(response).to render_text("Original")
    expect(response).to render_text("body text")
  end

  it "updates the record when an edit is submitted" do
    entry = Journal::Entry.create!(title: "Original", mood: "rough", body: "old")
    route = app.routes.resolve(:edit_entry, id: entry.id)
    controller = described_class.new(application: app, route: route, params: route.params)
    controller.dispatch(:edit)

    # Append to the title field, then save.
    %w[! !].each { |char| controller.dispatch_key(key_event(char)) }
    response = controller.dispatch_key(key_event("ctrl+s"))

    expect(entry.reload.title).to eq("Original!!")
    expect(response).to navigate_to(:entry, id: entry.id)
  end

  it "cancels back to the journal on escape" do
    ctrl.dispatch(:show)
    response = press(ctrl, "escape")
    expect(response).to navigate_to(:root)
  end
end
