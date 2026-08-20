# frozen_string_literal: true

module Charming
  # RenderArtifacts is what a pure view render produces: the painted *frame* string plus
  # the registration data the frame implies — *focus_slots* (focusable layout pane
  # names) and *mouse_targets* (named pane hit areas). Views stash them instead of
  # mutating the controller mid-render; the dispatch pipeline commits them when the
  # response actually paints.
  RenderArtifacts = Data.define(:frame, :focus_slots, :mouse_targets) do
    def initialize(frame: "", focus_slots: [], mouse_targets: [])
      super
    end

    # Merges several layouts' artifacts from one render: the last-rendered layout wins
    # for focus, and mouse targets concatenate in render order (overlays hit-test
    # last-wins via rfind).
    def self.merge(artifacts)
      new(
        focus_slots: artifacts.last&.focus_slots || [],
        mouse_targets: artifacts.flat_map(&:mouse_targets)
      )
    end
  end
end
