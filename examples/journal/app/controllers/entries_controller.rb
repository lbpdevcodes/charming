# frozen_string_literal: true

module Journal
  class EntriesController < ApplicationController
    focus_ring :entries, :sidebar

    key "n", :new_entry
    key "f", :toggle_favorite

    key "d", :request_delete
    on_select :entries, :open_entry
    on_submit :delete_confirm, :delete_entry
    on_cancel :delete_confirm, :cancel_delete

    def show
      entries.items = Entry.recent_first.to_a
      entries_state.selected_index = entries.selected_index
      render :show, entries_list: entries, palette: command_palette,
        delete_confirm: pending_delete && delete_confirm
    end

    def new_entry
      navigate :compose
    end

    def toggle_favorite
      entry = entries.selected_item
      return show unless entry

      entry.update!(favorite: !entry.favorite?)
      show_toast(entry.favorite? ? "Added to favorites ★" : "Removed from favorites")
      show
    end

    # Opens the delete-confirm modal for the highlighted entry. The modal scope
    # captures all keys until y / n / escape.
    def request_delete
      entry = entries.selected_item
      return show unless entry

      entries_state.pending_delete_id = entry.id
      focus.push_scope([:delete_confirm], origin: :modal)
      show
    end

    # The modal component the focused overlay scope routes keys to.
    def delete_confirm
      Journal::DeleteConfirm.new(entry_title: pending_delete.title, theme: theme)
    end

    def delete_entry(_value)
      entry = pending_delete
      entry&.destroy!
      close_delete_confirm
      show_toast("Deleted \"#{entry.title}\"", kind: :warn) if entry
      show
    end

    def cancel_delete
      close_delete_confirm
      show
    end

    # Enter on the list opens the selected entry.
    def open_entry(entry)
      navigate :entry, id: entry.id
    end

    # The selectable entry list, memoized so j/k selection survives across events.
    # `show` refreshes the items each render — the component holds the interaction
    # state, the items always reflect the database. entries_state mirrors the
    # selection so it can be restored after navigating away and back.
    def entries
      @entries ||= Charming::Components::List.new(
        items: Entry.recent_first.to_a,
        selected_index: entries_state.selected_index,
        height: [screen.height - 10, 3].max,
        label: :list_label.to_proc,
        theme: theme
      )
    end

    def status_hints
      [["enter", "open"], ["n", "new"], ["f", "fav"], ["d", "delete"], *super]
    end

    private

    def entries_state
      state(:entries, EntriesState)
    end

    def pending_delete
      id = entries_state.pending_delete_id
      id && Entry.find_by(id: id)
    end

    def close_delete_confirm
      entries_state.pending_delete_id = nil
      focus.pop_scope
    end
  end
end
