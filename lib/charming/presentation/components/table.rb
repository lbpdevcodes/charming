# frozen_string_literal: true

module Charming
  module Components
    # Table renders tabular data with a header row, a selected row highlight, and keyboard
    # navigation. Mouse clicks within the body area also select rows. The grid is drawn
    # with Charming's own width/border machinery (square border chars plus junctions);
    # the selected row is overlaid with reverse-video ANSI styling.
    class Table < Component
      include KeyboardHandler

      # Maps navigation keys to the instance methods that move the selection. Shared with
      # List and Viewport via KeyboardHandler.
      KEY_ACTIONS = {
        up: :move_up,
        down: :move_down,
        home: :move_home,
        end: :move_end,
        page_up: :page_up,
        page_down: :page_down
      }.freeze

      # Number of terminal rows occupied by the table's top border and header line. Used by
      # the mouse handler to translate absolute row coordinates to body rows.
      HEADER_HEIGHT = 2

      # The header row, the body rows, and the currently selected row index, respectively.
      attr_reader :header, :rows, :selected_index

      # *header* is an array of column labels. *rows* is the array of body rows (each either a
      # String, an Array, or a Hash of column-value pairs). *selected_index* defaults to 0.
      # *keymap* selects the keybinding style (`:vim` enables h/j/k/l → left/down/up/right).
      # *height* optionally limits the visible body rows; the window auto-scrolls to keep
      # the selection in view, and page up/down move by a full window.
      def initialize(header:, rows: [], selected_index: 0, keymap: :vim, theme: nil, height: nil)
        super(theme: theme)
        @header = Array(header).map(&:to_s)
        @rows = Array(rows)
        @selected_index = clamp_index(selected_index)
        @keymap = keymap
        @height = height
      end

      # Handles key events. Returns `[:selected, row]` on Enter; otherwise delegates to the
      # KeyboardHandler for navigation keys.
      def handle_key(event)
        return nil if rows.empty?

        case Charming.key_of(event)
        when :enter then [:selected, selected_row]
        else super
        end
      end

      # Handles mouse events: a click within the body area selects the clicked row
      # (relative to the visible window when a height is set).
      # Returns :handled on a successful click.
      def handle_mouse(event)
        return nil if rows.empty?
        return nil unless event.respond_to?(:click?) && event.click?

        clicked = event.y - HEADER_HEIGHT
        return nil if clicked.negative? || clicked >= visible_row_count

        @selected_index = viewport_start + clicked
        :handled
      end

      # Returns the currently selected row, or nil when the table is empty.
      def selected_row
        rows[selected_index]
      end

      # Replaces the body rows (e.g. after the underlying data changed) and
      # reclamps the selection. Lets a memoized table stay fresh: keep the component
      # in an ivar so its selection survives, then assign `table.rows = rows`
      # before each render.
      def rows=(new_rows)
        @rows = Array(new_rows)
        @selected_index = clamp_index(selected_index)
      end

      # Sorts the body rows by *column* (a header label or 0-based index).
      # Numeric-looking cells compare numerically; everything else as strings.
      # The sorted column is marked ▲/▼ in the rendered header. Returns self.
      def sort_by!(column, direction: :asc)
        @sort_column = column_index(column)
        @sort_direction = direction
        sorted = @rows.sort_by { |row| sort_key(row) }
        @rows = (direction == :desc) ? sorted.reverse : sorted
        self
      end

      # Sorts by *column*, flipping the direction on repeated calls for the same
      # column (ascending first). Returns self.
      def toggle_sort(column)
        flipping = @sort_column == column_index(column) && @sort_direction == :asc
        sort_by!(column, direction: flipping ? :desc : :asc)
      end

      # Renders the table to a string. Returns a placeholder when both header and rows are empty.
      def render
        return "(empty table)" if header.empty? && rows.empty?

        body = rows.map { |row| normalize_row(row) }
        columns = [header.length, *body.map(&:length)].max
        widths = column_widths(body, columns)
        lines = [border_line(widths, grid.top_left, grid_top_junction, grid.top_right)]
        lines << grid_line(marked_header_row(columns), widths) unless header.empty?
        window = body[viewport_start, visible_row_count] || []
        window.each_with_index do |cells, index|
          line = grid_line(cells, widths)
          lines << (((viewport_start + index) == selected_index) ? theme.selected.render(line) : line)
        end
        lines << border_line(widths, grid.bottom_left, grid_bottom_junction, grid.bottom_right)
        lines.join("\n")
      end

      private

      # The square border set the grid is drawn with.
      def grid
        UI::Border.fetch(:square)
      end

      # Column junction characters for the grid's top and bottom borders.
      def grid_top_junction = "┬"

      def grid_bottom_junction = "┴"

      # The display width of each column: the widest cell or header label, measured
      # with ANSI-aware display width so wide characters pad correctly.
      def column_widths(body, columns)
        lines = header.empty? ? body : [sort_marked_header, *body]
        Array.new(columns) do |column|
          UI::Width.widest(lines.map { |cells| cells[column].to_s })
        end
      end

      # The header row padded out to *columns* cells (short rows render empty cells).
      def marked_header_row(columns)
        sort_marked_header + Array.new([columns - header.length, 0].max, "")
      end

      # One body/header line: cells padded to column width, joined by verticals.
      def grid_line(cells, widths)
        padded = widths.each_with_index.map { |width, index| UI::Width.pad_to(cells[index].to_s, width) }
        "#{grid.vertical}#{padded.join(grid.vertical)}#{grid.vertical}"
      end

      # A top or bottom border line across the column widths.
      def border_line(widths, left, junction, right)
        "#{left}#{widths.map { |width| grid.horizontal * width }.join(junction)}#{right}"
      end

      # Coerces a *row* (Hash / String / Array) into a flat cell array matching the header.
      # Excess cells are merged into the last column with a space separator.
      def normalize_row(row)
        cells = case row
        when Hash then row.values
        when String then [row]
        else Array(row)
        end
        return cells if header.length <= 1 || cells.length <= header.length

        kept = cells.first(header.length - 1)
        merged = cells[(header.length - 1)..].join(" ")
        kept + [merged]
      end

      # The top body row of the visible window (0 when no height is set), keeping the
      # selection in view.
      def viewport_start
        return 0 unless @height

        Layout.selected_window_start(selected_index: selected_index, item_count: rows.length, window_size: @height)
      end

      # The number of body rows shown at once.
      def visible_row_count
        @height ? [@height, rows.length].min : rows.length
      end

      # Moves the selection up by one window.
      def page_up
        @selected_index = [selected_index - visible_row_count, 0].max
      end

      # Moves the selection down by one window.
      def page_down
        @selected_index = [selected_index + visible_row_count, rows.length - 1].min
      end

      # Moves the selection up one row.
      def move_up
        @selected_index -= 1 if selected_index.positive?
      end

      # Moves the selection down one row.
      def move_down
        @selected_index += 1 if selected_index < rows.length - 1
      end

      # Moves the selection to the first row.
      def move_home
        @selected_index = 0
      end

      # Moves the selection to the last row.
      def move_end
        @selected_index = rows.length - 1
      end

      # Resolves *column* (label or 0-based index) to a column index.
      def column_index(column)
        return column if column.is_a?(Integer) && column.between?(0, header.length - 1)

        header.index(column.to_s) ||
          raise(ArgumentError, "unknown column: #{column.inspect} (columns: #{header.join(", ")})")
      end

      # The comparable key for *row* at the active sort column: [0, number] for
      # numeric-looking cells, [1, string] otherwise, so mixed columns still sort.
      def sort_key(row)
        cell = normalize_row(row)[@sort_column].to_s
        cell.match?(/\A-?\d+(\.\d+)?\z/) ? [0, cell.to_f] : [1, cell]
      end

      # The header with the sorted column marked ▲ (ascending) or ▼ (descending).
      def sort_marked_header
        return header unless @sort_column

        marker = (@sort_direction == :desc) ? "▼" : "▲"
        header.each_with_index.map { |label, index| (index == @sort_column) ? "#{label} #{marker}" : label }
      end

      # Clamps *value* to the valid row range, defaulting to 0 when the table is empty.
      def clamp_index(value)
        return 0 if rows.empty?

        value.to_i.clamp(0, rows.length - 1)
      end
    end
  end
end
