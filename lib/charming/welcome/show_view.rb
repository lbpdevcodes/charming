# frozen_string_literal: true

module Charming
  module Welcome
    # The welcome screen body: a pastel Miami-deco skyline over the app name, tagline,
    # Charming version, and project link, centered on the terminal.
    class ShowView < Charming::View
      SKYLINE_COLORS = {
        "F" => "#f0437c", # flamingo
        "B" => "#f9cfd8", # blush
        "M" => "#bfe8dc", # mint
        "C" => "#f3e6c9", # cream
        "P" => "#fdfaf3", # plaster
        "G" => "#1d4b44"  # palm green
      }.freeze

      # Rows of [art, color mask] pairs; each mask letter colors the glyph above it.
      SKYLINE = [
        ["                         ▲                         ",
          "                         F                         "],
        ["                         █                         ",
          "                         F                         "],
        ["             ▄▄▄        ▄█▄        ▄▄▄             ",
          "             BBB        PFP        MMM             "],
        ["             ███       ▐███▌       ███             ",
          "             BBB       PPPPP       MMM             "],
        ["            █▀▀▀█      ▐███▌      █▀▀▀█            ",
          "            BBBBB      PPPPP      MMMMM            "],
        ["  ▄█▄       █████     ▐█████▌     █████       ▄█▄  ",
          "  GGG       BBBBB     PPPPPPP     MMMMM       GGG  "],
        ["   █   ▄▄▄ ██▀▀▀██    ▐█████▌    ██▀▀▀██ ▄▄▄   █   ",
          "   G   CCC BBBBBBB    PPPPPPP    MMMMMMM CCC   G   "],
        ["   █   ███ ███████   ▐███████▌   ███████ ███   █   ",
          "   G   CCC BBBBBBB   PPPPPPPPP   MMMMMMM CCC   G   "],
        ["   █   ███ ███████   ▐███████▌   ███████ ███   █   ",
          "   G   CCC BBBBBBB   PPPPPPPPP   MMMMMMM CCC   G   "],
        ["▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁",
          "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"]
      ].freeze
      SKYLINE_WIDTH = SKYLINE.map { |art, _mask| art.length }.max
      SKYLINE_HEIGHT = SKYLINE.length

      def render
        screen_layout(background: theme.background) do
          pane(style: centered) do
            welcome_content
          end
        end
      end

      private

      def centered
        style.align(:center).align_vertical(:middle)
      end

      def welcome_content
        column(*blocks, gap: 1, align: :center)
      end

      def blocks
        [skyline, heading, tagline, footer, hint].compact
      end

      def skyline
        return unless skyline_fits?

        column(*SKYLINE.map { |art, mask| paint_row(art, mask) })
      end

      # Leave room below the art for the heading, tagline, footer, and hint lines.
      def skyline_fits?
        layout_screen.width >= SKYLINE_WIDTH && layout_screen.height >= SKYLINE_HEIGHT + 8
      end

      def paint_row(art, mask)
        color_runs(art, mask).map { |run, key| paint(run, key) }.join
      end

      # Groups adjacent glyphs sharing a mask letter into [run, letter] pairs.
      def color_runs(art, mask)
        art.chars.zip(mask.chars)
          .chunk { |_glyph, key| key || " " }
          .map { |key, pairs| [pairs.map(&:first).join, key] }
      end

      def paint(run, key)
        color = SKYLINE_COLORS[key]
        color ? style.foreground(color).render(run) : run
      end

      def heading
        text app_name, style: theme.title
      end

      def tagline
        text "A Rails-inspired Ruby TUI framework", style: theme.text
      end

      def footer
        column(
          text("Charming v#{Charming::VERSION}", style: theme.muted),
          text("https://github.com/lbpdevcodes/charming", style: theme.muted),
          align: :center
        )
      end

      def hint
        text "Define a root route in config/routes.rb to replace this screen.", style: theme.muted
      end
    end
  end
end
