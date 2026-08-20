# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"

RSpec.describe Journal::EntriesController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }

  before do
    Journal::Entry.create!(title: "First", mood: "good", body: "one")
    Journal::Entry.create!(title: "Second", mood: "rough", body: "two")
  end

  it "renders the entry list" do
    response = build_controller(described_class, app: app).dispatch(:show)
    expect(response).to render_text("First")
    expect(response).to render_text("Second")
  end

  it "navigates to compose on n" do
    build_controller(described_class, app: app).dispatch(:show)
    response = press(described_class, "n", app: app)
    expect(response).to navigate_to(:compose)
  end

  it "opens the selected entry on enter" do
    build_controller(described_class, app: app).dispatch(:show)
    newest = Journal::Entry.recent_first.first
    response = press(described_class, "enter", app: app)
    expect(response).to navigate_to(:entry, id: newest.id)
  end

  it "toggles favorite with a toast" do
    build_controller(described_class, app: app).dispatch(:show)
    press(described_class, "f", app: app)

    expect(Journal::Entry.recent_first.first.favorite?).to be true
    expect(app.session[:toast][:message]).to include("favorites")
  end

  it "deletes through the confirm modal" do
    build_controller(described_class, app: app).dispatch(:show)
    doomed = Journal::Entry.recent_first.first

    press_sequence(described_class, %w[d y], app: app)

    expect(Journal::Entry.exists?(doomed.id)).to be false
  end

  it "cancels deletion with escape" do
    build_controller(described_class, app: app).dispatch(:show)
    press_sequence(described_class, %w[d escape], app: app)
    expect(Journal::Entry.count).to eq(2)
  end

  it "swallows other keys while the delete modal is open" do
    build_controller(described_class, app: app).dispatch(:show)
    response = press_sequence(described_class, %w[d n], app: app)
    expect(response).not_to navigate_to(:compose)
    expect(Journal::Entry.count).to eq(2)
  end

  it "renders the empty state without entries" do
    Journal::Entry.delete_all
    response = build_controller(described_class, app: app).dispatch(:show)
    expect(response).to render_text("No entries yet")
  end
end
