# frozen_string_literal: true

module Charming
  # Response encapsulates a controller's dispatch outcome — one of render text, navigate to another screen, or quit.
  # Rails-style factories (`render`, `navigate`, `quit`) serve as the public API and map to :kind values
  # that the Runtime interprets at the end of each event loop iteration.
  #
  # *escapes* carries any out-of-band terminal sequences (image transmissions, clipboard writes,
  # notifications, window-title changes) gathered during the dispatch. The Runtime flushes them straight
  # to the backend, bypassing the line-based frame pipeline. It is empty for ordinary responses.
  Response = Data.define(:kind, :body, :name, :params, :escapes) do
    # Factory constructing a Render response for displaying *body* text on the current screen. *escapes*
    # is the list of out-of-band sequences gathered during the dispatch (defaults to none).
    def self.render(body, escapes: [])
      new(kind: :render, body: body, name: nil, params: {}, escapes: escapes)
    end

    # Factory constructing a NavigateResponse routing to the screen registered under *name*
    # (a Symbol from config/routes.rb), passing *params* through to the controller.
    def self.navigate(name, **params)
      if name.is_a?(String) && name.start_with?("/")
        suggestion = name.split("/")[1].to_s.delete_prefix(":")
        raise ArgumentError,
          "String URL paths were removed. Use `navigate :#{suggestion}` with a screen name from config/routes.rb. See UPGRADING.md."
      end

      new(kind: :navigate, body: "", name: name.to_sym, params: params, escapes: [])
    end

    # Factory constructing a QuitResponse signalling termination of the top-level event loop.
    def self.quit
      new(kind: :quit, body: "", name: nil, params: {}, escapes: [])
    end

    # Returns `true` when this response is navigating to another screen.
    def navigate?
      kind == :navigate
    end

    # Returns `true` when this response requests quitting the application.
    def quit?
      kind == :quit
    end
  end
end
