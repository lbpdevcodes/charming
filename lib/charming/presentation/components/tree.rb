# frozen_string_literal: true

module Charming
  module Components
    # Tree renders a collapsible hierarchy (file explorers, nested data). Nodes are
    # hashes: `{label: "src", children: [...], expanded: true}` — `children` and
    # `expanded` are optional. Navigation: up/down move the cursor through *visible*
    # nodes, right expands, left collapses (or jumps to the parent), Enter returns
    # `[:selected, node]` for leaves and toggles branches. Mouse clicks move the cursor
    # and toggle branches.
    class Tree < Component
      include KeyboardHandler

      KEY_ACTIONS = {
        up: :move_up,
        down: :move_down,
        left: :collapse_or_parent,
        right: :expand,
        home: :move_home,
        end: :move_end
      }.freeze

      # The root node list and the cursor index into the visible-node list.
      attr_reader :nodes, :cursor_index

      # Replaces the root nodes (e.g. after the underlying data changed) and reclamps
      # the cursor. Expansion state lives in the node hashes, so fresh nodes render
      # with the expansion they carry. Lets a memoized tree stay fresh: keep the
      # component in a slot and assign `tree.nodes = rows` before each render.
      def nodes=(new_nodes)
        @nodes = new_nodes
        clamp_cursor
      end

      # *nodes* is the array of root node hashes (mutated in place to track expansion).
      # *height* optionally constrains the visible window.
      def initialize(nodes:, cursor_index: 0, height: nil, keymap: :vim, theme: nil)
        super(theme: theme)
        @nodes = nodes
        @cursor_index = cursor_index
        @height = height
        @keymap = keymap
        clamp_cursor
      end

      # Enter selects a leaf (`[:selected, node]`) or toggles a branch. Navigation keys
      # are handled by KeyboardHandler.
      def handle_key(event)
        node = current_node
        return nil unless node
        return select_or_toggle(node) if Charming.key_of(event) == :enter

        super
      end

      # A click moves the cursor to the clicked row; clicking a branch toggles it.
      def handle_mouse(event)
        return nil unless event.respond_to?(:click?) && event.click?

        clicked = viewport_start + event.y
        return nil if clicked >= visible_nodes.length || event.y.negative?

        @cursor_index = clicked
        node = current_node
        toggle(node) if branch?(node)
        :handled
      end

      # The node under the cursor (a node hash), or nil for an empty tree.
      def current_node
        visible_nodes[cursor_index]&.fetch(:node)
      end

      # Renders the visible window of the flattened tree.
      def render
        window = visible_nodes[viewport_start, viewport_height] || []
        window.each_with_index.map do |entry, index|
          render_node(entry, viewport_start + index)
        end.join("\n")
      end

      private

      # Flattens the tree into visible rows: `{node:, depth:}` entries, skipping
      # children of collapsed branches.
      def visible_nodes
        flatten(nodes, 0)
      end

      def flatten(list, depth)
        Array(list).flat_map do |node|
          entry = [{node: node, depth: depth}]
          entry += flatten(node[:children], depth + 1) if branch?(node) && node[:expanded]
          entry
        end
      end

      # Renders one row: indentation, expansion marker, label; cursor row uses the
      # selected style.
      def render_node(entry, index)
        node = entry.fetch(:node)
        marker = if branch?(node)
          node[:expanded] ? "▾ " : "▸ "
        else
          "  "
        end
        line = "#{"  " * entry.fetch(:depth)}#{marker}#{node[:label]}"
        (index == cursor_index) ? theme.selected.render(line) : line
      end

      def branch?(node)
        node && node[:children] && !node[:children].empty?
      end

      def select_or_toggle(node)
        return [:selected, node] unless branch?(node)

        toggle(node)
        :handled
      end

      def toggle(node)
        node[:expanded] = !node[:expanded]
      end

      def expand
        node = current_node
        node[:expanded] = true if branch?(node)
      end

      # Collapses an expanded branch, or moves the cursor to the parent of a leaf or
      # collapsed node.
      def collapse_or_parent
        node = current_node
        if branch?(node) && node[:expanded]
          node[:expanded] = false
        else
          parent = parent_index(cursor_index)
          @cursor_index = parent if parent
        end
      end

      # Index of the nearest row above with a smaller depth (the parent), or nil.
      def parent_index(index)
        rows = visible_nodes
        depth = rows[index]&.fetch(:depth)
        return nil unless depth&.positive?

        (index - 1).downto(0).find { |candidate| rows[candidate].fetch(:depth) < depth }
      end

      def move_up
        @cursor_index -= 1 if cursor_index.positive?
      end

      def move_down
        @cursor_index += 1 if cursor_index < visible_nodes.length - 1
      end

      def move_home
        @cursor_index = 0
      end

      def move_end
        @cursor_index = [visible_nodes.length - 1, 0].max
      end

      # Top row of the visible window, keeping the cursor in view.
      def viewport_start
        return 0 unless @height

        Layout.selected_window_start(selected_index: cursor_index, item_count: visible_nodes.length, window_size: @height)
      end

      def viewport_height
        @height || visible_nodes.length
      end

      def clamp_cursor
        max = [visible_nodes.length - 1, 0].max
        @cursor_index = cursor_index.clamp(0, max)
      end
    end
  end
end
