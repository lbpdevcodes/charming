# frozen_string_literal: true

module Journal
  class ReaderController < ApplicationController
    focus_ring :body, :sidebar

    before_action :load_entry
    rescue_from ActiveRecord::RecordNotFound, with: :entry_missing

    key "e", :edit_entry
    key "f", :toggle_favorite
    key "d", :request_delete
    key "escape", :back_to_list
    on_submit :delete_confirm, :delete_entry
    on_cancel :delete_confirm, :cancel_delete

    # The markdown body in a scrollable viewport (j/k/arrows/page keys via focus),
    # memoized for the screen's lifetime. Built from current_entry, not @entry:
    # slot factories run on key dispatch paths where before_action hasn't run.
    slot(:body) do
      Charming::Components::Viewport.new(
        content: rendered_markdown,
        width: [screen.width - 32, 40].max,
        height: [screen.height - 12, 5].max,
        offset: entry_state.scroll_offset,
        wrap: true
      )
    end

    def show
      entry_state.scroll_offset = body.offset
      render :show, entry: @entry, body_pane: body, palette: command_palette,
        delete_confirm: entry_state.pending_delete && delete_confirm
    end

    def edit_entry
      navigate :edit_entry, id: @entry.id
    end

    def toggle_favorite
      @entry.update!(favorite: !@entry.favorite?)
      show_toast(@entry.favorite? ? "Added to favorites ★" : "Removed from favorites")
      show
    end

    def back_to_list
      navigate :root
    end

    def request_delete
      entry_state.pending_delete = true
      focus.push_scope([:delete_confirm], origin: :modal)
      show
    end

    # Note: component dispatch (the y/n keys inside the modal) doesn't run actions,
    # so before_action hasn't loaded @entry here — load explicitly.
    def delete_confirm
      Journal::DeleteConfirm.new(entry_title: current_entry.title, theme: theme)
    end

    def delete_entry(_value)
      entry = current_entry
      title = entry.title
      entry.destroy!
      close_delete_confirm
      show_toast("Deleted \"#{title}\"", kind: :warn)
      navigate :root
    end

    def cancel_delete
      close_delete_confirm
      show
    end

    def status_hints
      [["j/k", "scroll"], ["e", "edit"], ["f", "fav"], ["d", "delete"], ["esc", "back"], *super]
    end

    private

    def load_entry
      @entry = Entry.find(params.fetch(:id))
    end

    # The routed entry, loadable outside the action pipeline (component hooks and
    # key-dispatch probes). Nil when the id is stale — callers must tolerate that;
    # the show action still raises via load_entry so rescue_from renders the
    # not-found screen.
    def current_entry
      @entry ||= Entry.find_by(id: params[:id])
    end

    # rescue_from handler: friendly screen instead of a crash for bad ids.
    def entry_missing(_error)
      render "Entry not found.\n\nPress escape to return to the journal."
    end

    def rendered_markdown
      entry = current_entry
      return "Entry not found." unless entry

      Charming::Components::Markdown.new(
        content: "# #{entry.title}\n\n#{entry.body}",
        theme: theme
      ).render
    end

    def entry_state
      state(:"entry_#{params[:id]}", EntryState)
    end

    def close_delete_confirm
      entry_state.pending_delete = false
      focus.pop_scope
    end
  end
end
