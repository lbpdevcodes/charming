# frozen_string_literal: true

require_relative "../spec_helper"
require "charming/test_helper"
require "fileutils"

RSpec.describe Journal::StatsController do
  include Charming::TestHelper

  let(:app) { Journal::Application.new }
  let(:ctrl) { build_controller(described_class, app: app) }

  before do
    Journal::Entry.create!(title: "One", mood: "good", body: "a")
    Journal::Entry.create!(title: "Two", mood: "good", body: "b")
    Journal::Entry.create!(title: "Three", mood: "rough", body: "c")
  end

  it "renders mood counts and totals" do
    response = ctrl.dispatch(:show)
    expect(response).to render_text("Writing stats")
    expect(response).to render_text("3 entries")
    expect(response).to render_text("good (2)")
    expect(response).to render_text("rough (1)")
  end

  it "exports entries with progress and completion events" do
    queue = Thread::Queue.new
    app.task_executor = Charming::Tasks::InlineExecutor.new(queue)

    ctrl.dispatch(:show)
    press(ctrl, "x")

    events = []
    events << queue.pop(true) until queue.empty?
    progress_events = events.select { |e| e.is_a?(Charming::Events::TaskProgressEvent) }
    completion = events.find { |e| e.is_a?(Charming::Events::TaskEvent) }

    expect(progress_events.length).to eq(3)
    expect(progress_events.last.fraction).to eq(1.0)
    expect(completion.value).to eq(3)
    expect(File.read(File.expand_path("../../tmp/journal_export.md", __dir__))).to include("# Three")
  end
end
