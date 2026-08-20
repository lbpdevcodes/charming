# frozen_string_literal: true

module Charming
  module Components
    # HelpOverlay renders a controller's key bindings as a two-column cheat-sheet inside
    # a Modal — the classic `?` help screen. Build it straight from a controller class:
    #
    #   HelpOverlay.for_controller(self.class, theme: theme)
    #
    # or with explicit entries:
    #
    #   HelpOverlay.new(bindings: {"q" => "Quit", "ctrl+p" => "Command palette"})
    #
    # Any key dismisses it (`handle_key` returns Result.cancelled).
    class HelpOverlay < Component
      DEFAULT_TITLE = "Keyboard Shortcuts"
      DEFAULT_WIDTH = 44

      # Builds an overlay from a controller class's `key_bindings` (key → action name).
      # Action names are humanized into descriptions ("open_command_palette" → "Open command palette").
      def self.for_controller(controller_class, title: DEFAULT_TITLE, theme: nil)
        bindings = controller_class.key_bindings.transform_values do |action|
          action.to_s.tr("_", " ").capitalize
        end
        new(bindings: bindings, title: title, theme: theme)
      end

      # *bindings* maps key names (symbols or strings) to description strings.
      def initialize(bindings:, title: DEFAULT_TITLE, width: DEFAULT_WIDTH, theme: nil)
        super(theme: theme)
        @bindings = bindings
        @title = title
        @width = width
      end

      # Free-typed characters belong to this component while it is focused.
      def captures_text?
        true
      end

      # Any key dismisses the overlay.
      def handle_key(_event)
        Result.cancelled
      end

      # Renders the bindings table inside a titled modal.
      def render
        render_component(Modal.new(content: table, title: @title, width: @width, theme: theme))
      end

      private

      # The two-column key/description table, keys right-padded to align.
      def table
        return theme.muted.render("No key bindings") if @bindings.empty?

        key_width = @bindings.keys.map { |key| key.to_s.length }.max
        @bindings.map do |key, description|
          padded = key.to_s.ljust(key_width)
          "#{theme.title.render(padded)}  #{description}"
        end.join("\n")
      end
    end
  end
end
