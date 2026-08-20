# frozen_string_literal: true

module Journal
  class ComposeController < ApplicationController
    focus_ring :entry_form, :sidebar

    before_action :prepare_form_state
    on_submit :entry_form, :save_entry
    on_cancel :entry_form, :cancel_edit

    def show
      render :show, form: entry_form, editing: editing_entry, palette: command_palette
    end

    # `:edit_entry` lands here; same screen, form pre-seeded from the record.
    def edit
      show
    end

    # Ctrl+S (or Enter on the last field) with valid values lands here.
    def save_entry(values)
      entry = persist_entry(values)
      reset_form_state
      show_toast(editing_entry ? "Updated \"#{entry.title}\"" : "Saved \"#{entry.title}\"")
      navigate :entry, id: entry.id
    end

    def cancel_edit
      reset_form_state
      editing_entry ? navigate(:entry, id: editing_entry.id) : navigate(:root)
    end

    def entry_form
      entry = editing_entry
      form(:entry) do |f|
        f.input :title, required: true, placeholder: "What happened today?",
          value: entry&.title.to_s
        f.select :mood, options: Entry::MOODS,
          option_label: ->(m) { "#{Entry::MOOD_EMOJI.fetch(m)} #{m}" },
          selected_index: entry ? Entry::MOODS.index(entry.mood) || 0 : 0
        f.textarea :body, height: 10, placeholder: "Write in Markdown…",
          value: entry&.body.to_s
        f.confirm :favorite, label: "Mark as favorite", value: !!entry&.favorite?
        f.note "enter for new line in body · tab next field · ctrl+s save · esc cancel"
      end
    end

    def status_hints
      [["tab", "next field"], ["ctrl+s", "save"], ["esc", "cancel"], *super]
    end

    private

    # The entry being edited (`/entries/:id/edit`), or nil when composing fresh.
    def editing_entry
      return nil unless params[:id]

      @editing_entry ||= Entry.find_by(id: params[:id])
    end

    # Form state persists in the session across dispatches; when switching between
    # "new" and "edit" (or editing a different entry) the stale draft must be cleared
    # so the form re-seeds from the right defaults.
    def prepare_form_state
      mode = editing_entry ? "edit-#{editing_entry.id}" : "new"
      return if session[:compose_mode] == mode

      session[:compose_mode] = mode
      session[:forms]&.delete(:entry)
    end

    def reset_form_state
      session.delete(:compose_mode)
      session[:forms]&.delete(:entry)
    end

    def persist_entry(values)
      attributes = {
        title: values[:title],
        mood: values[:mood],
        body: values[:body],
        favorite: values[:favorite]
      }
      if editing_entry
        editing_entry.update!(attributes)
        editing_entry
      else
        Entry.create!(attributes)
      end
    end
  end
end
