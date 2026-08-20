# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"

RSpec.describe Journal::ComposeController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }

  def type(string)
    string.chars.each do |char|
      press(described_class, char, app: app)
    end
  end

  it "renders the new-entry form" do
    response = build_controller(described_class, app: app).dispatch(:show)
    expect(response).to render_text("New entry")
    expect(response).to render_text("Title")
    expect(response).to render_text("Mood")
  end

  it "creates an entry through the form" do
    build_controller(described_class, app: app).dispatch(:show)
    type("Hello")
    response = press(described_class, "ctrl+s", app: app)

    entry = Journal::Entry.find_by(title: "Hello")
    expect(entry).not_to be_nil
    expect(entry.mood).to eq("good")
    expect(response).to navigate_to(:entry, id: entry.id)
  end

  it "keeps the form open with errors when the title is missing" do
    build_controller(described_class, app: app).dispatch(:show)
    response = press(described_class, "ctrl+s", app: app)

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
    described_class.new(application: app, route: route, params: route.params).dispatch(:edit)

    # Append to the title field, then save.
    %w[! !].each do |char|
      described_class.new(application: app, route: route, params: route.params,
        event: key_event(char)).dispatch_key
    end
    response = described_class.new(application: app, route: route, params: route.params,
      event: key_event("ctrl+s")).dispatch_key

    expect(entry.reload.title).to eq("Original!!")
    expect(response).to navigate_to(:entry, id: entry.id)
  end

  it "cancels back to the journal on escape" do
    build_controller(described_class, app: app).dispatch(:show)
    response = press(described_class, "escape", app: app)
    expect(response).to navigate_to(:root)
  end
end
