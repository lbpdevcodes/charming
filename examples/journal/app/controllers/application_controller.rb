# frozen_string_literal: true

module Journal
  class ApplicationController < Charming::Controller
    include Charming::Shell::Sidebar
    include Charming::Shell::Palette

    layout Layouts::ApplicationLayout
    focus_ring :sidebar, :content

    key "ctrl+p", :open_command_palette, scope: :global
    key "?", :open_help, scope: :global
    key "q", :quit, scope: :global
    on_cancel :help_overlay, :close_help

    timer :toast_expiry, every: 0.5, action: :expire_toast

    # The keyboard-shortcut overlay, memoized per screen (content is derived from the
    # controller class, so it never changes mid-screen).
    slot(:help_overlay) { Charming::Components::HelpOverlay.for_controller(self.class, theme: theme) }

    command "Entries" do
      navigate :root
    end

    command "Compose" do
      navigate :compose
    end

    command "Stats" do
      navigate :stats
    end

    command "Theme", :open_theme_palette
    command "Close palette", :close_command_palette
    command "Quit app", :quit

    # The sidebar lists only static screens — the :entry/:edit_entry screens take
    # an id param, so they are reachable by selecting an entry, not from the nav.
    def sidebar_routes
      application.routes.all.reject { |route| %i[entry edit_entry].include?(route.name) }
    end

    # --- Toasts -----------------------------------------------------------------

    # Shows an auto-dismissing toast (rendered by the layout as an overlay).
    def show_toast(message, kind: :success)
      session[:toast] = {message: message, kind: kind, expires_at: Time.now.to_f + 2.5}
    end

    # Timer action: clears the toast once its deadline passes. Renders only when
    # something actually changed.
    def expire_toast
      toast = session[:toast]
      return unless toast
      return if Time.now.to_f < toast[:expires_at]

      session.delete(:toast)
      render_default_action
    end

    # --- Help overlay -----------------------------------------------------------

    # Opens the keyboard-shortcut overlay; any key dismisses it.
    def open_help
      session[:help_open] = true
      focus.push_scope([:help_overlay], origin: :modal)
      render_default_action
    end

    def close_help
      session.delete(:help_open)
      focus.pop_scope
      render_default_action
    end

    # --- Status bar -------------------------------------------------------------

    # Key hints shown in the status bar; screens override to add their own.
    def status_hints
      [["ctrl+p", "commands"], ["?", "help"], ["q", "quit"]]
    end

    def entry_count
      Entry.count
    end
  end
end
