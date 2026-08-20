# frozen_string_literal: true

RSpec.describe Charming::Components::Table do
  def key(name)
    Charming::Events::KeyEvent.new(key: name)
  end

  def mouse(x: 0, y: 0, button: 0)
    Charming::Events::MouseEvent.new(button: button, x: x, y: y)
  end

  describe "#initialize" do
    it "sets header from array argument" do
      table = described_class.new(header: %w[Name Age])

      expect(table.header).to eq(%w[Name Age])
    end

    it "wraps scalar header in an array" do
      table = described_class.new(header: "Name")

      expect(table.header).to eq(["Name"])
    end

    it "converts header values to strings" do
      table = described_class.new(header: ["Name", 42])

      expect(table.header).to eq(%w[Name 42])
    end

    it "defaults rows to empty array" do
      table = described_class.new(header: %w[A B])

      expect(table.rows).to be_empty
    end

    it "defaults selected_index to 0" do
      table = described_class.new(header: %w[Name Age], rows: %w[foo bar])

      expect(table.selected_index).to eq(0)
    end

    it "clamps selected_index when out of range" do
      table = described_class.new(header: %w[A B], rows: %w[one], selected_index: 5)

      expect(table.selected_index).to eq(0)
    end

    it "returns empty string for both header and rows" do
      table = described_class.new(header: [], rows: [])

      expect(table.header).to be_empty
      expect(table.rows).to be_empty
    end
  end

  describe "#handle_key :up/:down" do
    it "moves selection down" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      expect(table.handle_key(key(:down))).to eq(Charming::Components::Result.handled)
      expect(table.selected_index).to eq(1)
    end

    it "moves selection up" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c], selected_index: 2)

      expect(table.handle_key(key(:up))).to eq(Charming::Components::Result.handled)
      expect(table.selected_index).to eq(1)
    end

    it "supports vim navigation keys by default" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      expect(table.handle_key(key(:j))).to eq(Charming::Components::Result.handled)
      table.handle_key(key(:k))

      expect(table.selected_index).to eq(0)
    end

    it "clamps at the top boundary" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      table.handle_key(key(:up))
      expect(table.selected_index).to eq(0)
    end

    it "clamps at the bottom boundary" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      table.handle_key(key(:down))
      table.handle_key(key(:down))
      table.handle_key(key(:down))
      expect(table.selected_index).to eq(2)
    end
  end

  describe "#handle_key :home/:end" do
    it "jumps to first row with home" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c d e])

      table.handle_key(key(:down))
      table.handle_key(key(:down))

      expect(table.selected_index).to eq(2)

      table.handle_key(key(:home))
      expect(table.selected_index).to eq(0)
    end

    it "jumps to last row with end" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c d e])

      table.handle_key(key(:end))
      expect(table.selected_index).to eq(4)
    end
  end

  describe "#handle_key :enter" do
    it "returns selected_row when rows exist" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      result = table.handle_key(key(:enter))
      expect(result).to eq(Charming::Components::Result.selected("a"))
    end

    it "returns row data on enter" do
      table = described_class.new(
        header: %w[Name Age],
        rows: [%w[Alice 30], ["Bob", 25]],
        selected_index: 1
      )

      result = table.handle_key(key(:enter))
      expect(result).to eq(Charming::Components::Result.selected(["Bob", 25]))
    end

    it "returns nil rows when empty" do
      table = described_class.new(header: %w[A B])

      expect(table.handle_key(key(:enter))).to be_nil
    end

    it "return nil for non-enter keys" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b])

      expect(table.handle_key(key(:q))).to be_nil
    end

    it "does not consume unknown keys via KeyboardHandler" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      result = table.handle_key(key(:left))
      expect(result).to be_nil
    end
  end

  describe "#render empty table" do
    it "renders (empty table)" do
      table = described_class.new(header: [], rows: [])

      expect(table.render).to eq("(empty table)")
    end

    it "header is non-empty" do
      table = described_class.new(header: %w[A B], rows: [])

      expect(table.header.map(&:length)).to all(be >= 1)
      expect(table.rows).to be_empty
    end
  end

  describe "#render auto-fit columns" do
    let(:theme) { Charming::UI::Theme.default }

    it "renders a header row and data rows with auto-fitted columns from strings" do
      table = described_class.new(
        header: %w[Name Age City],
        rows: [%w[Alice 30 New York], ["Bob", "25", "SF"]],
        theme: theme
      )

      output = table.render
      expect(output).to include("Name")
      expect(output).to include("Alice")
      expect(output).to include("┌")
    end

    it "renders unicode borders" do
      table = described_class.new(
        header: %w[Col],
        rows: [%w[data]],
        theme: theme
      )

      output = table.render
      expect(output).to match(/┌.*┐/)
      expect(output).to match(/│.*│/)
    end

    it "renders auto-fits wide values expand columns" do
      table = described_class.new(
        header: %w[Short Long],
        rows: [%w[a "Very long value that exceeds the first column width significantly"]],
        theme: theme
      )

      output = table.render
      expect(output).to include("a")
      expect(output).to include("Very long value that exceeds the first column width significantly")
    end

    it "merges trailing cells into the last column when row has more cells than header" do
      table = described_class.new(
        header: %w[Name Address],
        rows: [["Alice", "123", "Main", "St"]],
        theme: theme
      )

      expect(table.render).to include("123 Main St")
    end

    it "renders mixed row types (arrays and hashes)" do
      row = {name: "Alice", age: 30}
      table = described_class.new(
        header: %w[Name Age],
        rows: [row],
        theme: theme
      )

      output = table.render
      expect(output).to include("Alice")
    end

    it "renders the exact unicode grid (characterizes the tty-table replacement)" do
      table = described_class.new(header: %w[Name Age], rows: [["Ada", 36], ["Grace", 41]], theme: theme)

      lines = table.render.lines(chomp: true).map { |line| Charming::UI::Width.strip_ansi(line) }

      expect(lines).to eq([
        "┌─────┬───┐",
        "│Name │Age│",
        "│Ada  │36 │",
        "│Grace│41 │",
        "└─────┴───┘"
      ])
    end

    it "pads wide-character cells by display width" do
      table = described_class.new(header: ["N"], rows: [["日本"]], theme: theme)

      lines = table.render.lines(chomp: true).map { |line| Charming::UI::Width.strip_ansi(line) }

      expect(lines).to eq(["┌────┐", "│N   │", "│日本│", "└────┘"])
    end

    it "pads short rows with empty cells" do
      table = described_class.new(header: %w[Name Age], rows: [["Ada"]], theme: theme)

      lines = table.render.lines(chomp: true).map { |line| Charming::UI::Width.strip_ansi(line) }

      expect(lines).to include("│Ada │   │")
    end

    it "renders the header and borders when there are no rows" do
      table = described_class.new(header: %w[Name Age], rows: [])

      lines = table.render.lines(chomp: true).map { |line| Charming::UI::Width.strip_ansi(line) }

      expect(lines).to eq(["┌────┬───┐", "│Name│Age│", "└────┴───┘"])
    end

    it "renders rows without a header line when the header is empty" do
      table = described_class.new(header: [], rows: [["a", "bb"]], theme: theme)

      lines = table.render.lines(chomp: true).map { |line| Charming::UI::Width.strip_ansi(line) }

      expect(lines).to eq(["┌─┬──┐", "│a│bb│", "└─┴──┘"])
    end
  end

  describe "#render selection highlighting" do
    let(:theme) { Charming::UI::Theme.default }

    it "highlights the selected row using the theme's selected style" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c],
        selected_index: 1,
        theme: theme
      )

      output = table.render
      lines = output.lines(chomp: true)
      b_line = lines.find { |l| l.include?("b") && !l.strip.match?(/┌|└|├|┤/) }
      selected_render = theme.selected.render("b")
      # The row for "b" should contain the theme-styled version of "b"
      expect(b_line).to include(selected_render[0, 4])
    end

    it "highlights exactly one row when selected_index is set" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c],
        selected_index: 0,
        theme: theme
      )

      # The selected row should be styled differently from unselected ones
      output = table.render
      selected_rendered = theme.selected.render("a")
      lines_with_selected = output.lines(chomp: true).select { |l| l.include?(selected_rendered[0, 4]) }
      expect(lines_with_selected.length).to eq(1)
      expect(lines_with_selected.first).to include("a")
    end
  end

  describe "#handle_mouse" do
    it "selects row on click within body area" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c]
      )

      result = table.handle_mouse(mouse(x: 5, y: 4))
      expect(result).to eq(Charming::Components::Result.handled)
      expect(table.selected_index).to eq(2)
    end

    it "does not click on header row" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c]
      )

      result = table.handle_mouse(mouse(x: 5, y: 0))
      expect(result).to be_nil
      expect(table.selected_index).to eq(0)
    end

    it "click ignores clicks outside row bounds" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c]
      )

      result = table.handle_mouse(mouse(x: 5, y: 10))
      expect(result).to be_nil
      expect(table.selected_index).to eq(0)
    end

    it "ignores non-click mouse events" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b]
      )

      scroll = Charming::Events::MouseEvent.new(button: 64, x: 0, y: 2)
      expect(table.handle_mouse(scroll)).to be_nil
    end

    it "handles single row table" do
      table = described_class.new(
        header: %w[Name],
        rows: %w[only]
      )

      # Click on the body row (HEADER_HEIGHT = 2, single row sits at y = 2).
      result = table.handle_mouse(mouse(x: 0, y: 2))
      expect(result).to eq(Charming::Components::Result.handled)
      expect(table.selected_index).to eq(0)
    end

    it "returns nil for clicks on the bottom border" do
      table = described_class.new(header: %w[Name Age], rows: %w[a b c])

      # 3 body rows occupy y = 2..4; bottom border lives at y = 5.
      result = table.handle_mouse(mouse(x: 0, y: 5))
      expect(result).to be_nil
      expect(table.selected_index).to eq(0)
    end

    it "returns nil and leaves selection alone when rows are empty" do
      table = described_class.new(header: %w[Name Age], rows: [])

      result = table.handle_mouse(mouse(x: 0, y: 2))
      expect(result).to be_nil
      expect(table.selected_index).to eq(0)
    end

    it "no click event" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c]
      )

      expect(table.handle_mouse(mouse)).to be_nil
    end
  end

  describe "#selected_row" do
    it "returns the row at selected_index" do
      table = described_class.new(
        header: %w[Name Age],
        rows: %w[a b c],
        selected_index: 1
      )

      expect(table.selected_row).to eq("b")
    end

    it "returns array row when stored as arrays" do
      # Test array rows stored as arrays
      table = described_class.new(
        header: %w[Name Age],
        rows: [%w[Alice 30]],
        selected_index: 0
      )

      expect(table.selected_row).to eq(%w[Alice 30])
    end
  end

  describe "edge cases" do
    it "handles single row table navigation" do
      table = described_class.new(
        header: %w[Name],
        rows: %w[only]
      )

      table.handle_key(key(:up))
      expect(table.selected_index).to eq(0)

      table.handle_key(key(:down))
      expect(table.selected_index).to eq(0)
    end

    it "empty rows return nil for selected_row" do
      table = described_class.new(header: %w[A B])

      expect(table.selected_row).to be_nil
    end

    it "clamp handles zero-row edge case" do
      table = described_class.new(header: %w[A B], rows: [], selected_index: 0)

      expect(table.selected_index).to eq(0)
    end
  end

  describe "#rows=" do
    it "replaces the rows while keeping a valid selection" do
      table = described_class.new(header: %w[Name], rows: [["a"], ["b"]], selected_index: 1)

      table.rows = [["c"], ["d"]]

      expect(table.rows).to eq([["c"], ["d"]])
      expect(table.selected_row).to eq(["d"])
    end

    it "clamps the selection when the new rows are fewer" do
      table = described_class.new(header: %w[Name], rows: [["a"], ["b"], ["c"]], selected_index: 2)

      table.rows = [["a"]]

      expect(table.selected_row).to eq(["a"])
    end

    it "resets the selection when the new rows are empty" do
      table = described_class.new(header: %w[Name], rows: [["a"]], selected_index: 0)

      table.rows = []

      expect(table.selected_row).to be_nil
      expect(table.selected_index).to eq(0)
    end
  end

  describe "sorting" do
    let(:table) do
      described_class.new(
        header: %w[Name Stars],
        rows: [["bubbletea", "27000"], ["charming", "120"], ["lipgloss", "8000"]],
        theme: Charming::UI::Theme.default
      )
    end

    it "sorts rows by a named column ascending" do
      table.sort_by!("Name")

      expect(table.rows.map(&:first)).to eq(%w[bubbletea charming lipgloss])
    end

    it "sorts descending when asked" do
      table.sort_by!("Name", direction: :desc)

      expect(table.rows.map(&:first)).to eq(%w[lipgloss charming bubbletea])
    end

    it "sorts numeric columns numerically, by index" do
      table.sort_by!(1)

      expect(table.rows.map(&:last)).to eq(%w[120 8000 27000])
    end

    it "toggles direction when re-sorting the same column" do
      table.toggle_sort("Stars")
      table.toggle_sort("Stars")

      expect(table.rows.map(&:last)).to eq(%w[27000 8000 120])
    end

    it "marks the sorted column in the rendered header" do
      table.sort_by!("Stars")

      expect(table.render).to include("Stars ▲")

      table.sort_by!("Stars", direction: :desc)

      expect(table.render).to include("Stars ▼")
    end

    it "rejects unknown columns" do
      expect { table.sort_by!("Forks") }.to raise_error(ArgumentError, /unknown column/)
    end
  end
end
