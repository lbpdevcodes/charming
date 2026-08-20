# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"

RSpec.describe Journal::EntriesController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }
  let(:ctrl) { build_controller(described_class, app: app) }

  before do
    Journal::Entry.create!(title: "First", mood: "good", body: "one")
    Journal::Entry.create!(title: "Second", mood: "rough", body: "two")
  end

  it "renders the entry list" do
    response = ctrl.dispatch(:show)
    expect(response).to render_text("First")
    expect(response).to render_text("Second")
  end

  it "navigates to compose on n" do
    ctrl.dispatch(:show)
    response = press(ctrl, "n")
    expect(response).to navigate_to(:compose)
  end

  it "opens the selected entry on enter" do
    ctrl.dispatch(:show)
    newest = Journal::Entry.recent_first.first
    response = press(ctrl, "enter")
    expect(response).to navigate_to(:entry, id: newest.id)
  end

  it "toggles favorite with a toast" do
    ctrl.dispatch(:show)
    press(ctrl, "f")

    expect(Journal::Entry.recent_first.first.favorite?).to be true
    expect(app.session[:toast][:message]).to include("favorites")
  end

  it "deletes through the confirm modal" do
    ctrl.dispatch(:show)
    doomed = Journal::Entry.recent_first.first

    press_sequence(ctrl, %w[d y])

    expect(Journal::Entry.exists?(doomed.id)).to be false
  end

  it "cancels deletion with escape" do
    ctrl.dispatch(:show)
    press_sequence(ctrl, %w[d escape])
    expect(Journal::Entry.count).to eq(2)
  end

  it "swallows other keys while the delete modal is open" do
    ctrl.dispatch(:show)
    response = press_sequence(ctrl, %w[d n])
    expect(response).not_to navigate_to(:compose)
    expect(Journal::Entry.count).to eq(2)
  end

  it "renders the empty state without entries" do
    Journal::Entry.delete_all
    response = ctrl.dispatch(:show)
    expect(response).to render_text("No entries yet")
  end
end
