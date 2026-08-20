# frozen_string_literal: true

Journal::Application.routes do
  root "entries#show", title: "Entries"
  screen :compose, "compose#show", title: "Compose"
  screen :stats, "stats#show", title: "Stats"
  screen :entry, "reader#show", title: "Entry"
  screen :edit_entry, "compose#edit", title: "Edit"
end
