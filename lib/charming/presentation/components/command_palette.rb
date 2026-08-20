# frozen_string_literal: true

module Charming
  module Components
    # CommandPalette renders a fuzzy-searchable command picker UI. It wraps a TextInput for search
    # input and a List for result display, dispatching key events between them. Users type to filter
    # the registered commands by label match, navigate with up/down/home/end keys (delegated to List),
    # confirm a selection with Enter (returns Result.selected(command)), or cancel with Escape (returns
    # Result.cancelled).
    # State is serializable as a hash of value/cursor/selected_index for session persistence.
    class CommandPalette < Component
      Command = Data.define(:label, :value)

      # A single command palette entry: a human-readable +label+ and a callable or
      # method symbol +value+ that gets executed when the user selects it.
      attr_reader :commands, :input

      # Initializes the dropdown widget with a list of Command entries and search
      # parameters for building the underlying TextInput (placeholder text, cursor
      # position, value) and List (display height, initial selection). Returns void;
      # the state is later serializable via +state+ for session persistence.
      def initialize(commands:, placeholder: "Search commands", height: nil, value: "", cursor: nil, selected_index: 0, theme: nil)
        super(theme: theme)
        @commands = commands
        @height = height
        @input = TextInput.new(value: value, placeholder: placeholder, cursor: cursor)
        @list = build_list(selected_index: selected_index)
      end

      # Returns the currently displayed Command entry in the List at the time of calling.
      # Returns nil if no entry is highlighted (i.e., user has opened the palette but not
      # moved the selection). Useful for retrieving the result after key handling.
      def selected_command
        list.selected_item
      end

      # Collects the current state of the TextInput and List into a serializable hash
      # suitable for round-trip storage in session. Returns {value:, cursor:, selected_index:}.
      def state
        {
          value: input.value,
          cursor: input.cursor,
          selected_index: list.selected_index
        }
      end

      # Free-typed characters belong to this component while it is focused.
      def captures_text?
        true
      end

      # Handles key events by routing them to the appropriate sub-component: Escape kills the
      # palette returning Result.cancelled; up/down/home/end keys go to the List selection handler
      # via handle_list_key; all other keys (including typed characters) are passed to the TextInput
      # which manages cursor position and input filtering. If a list key match fails, falls through
      # to the TextInput handler. Returns nil if no handler consumed the event, or Result.cancelled
      # when Escape is pressed.
      def handle_key(event)
        key = Charming.key_of(event)
        return Result.cancelled if key == :escape

        return handle_list_key(event) if list_key?(key)

        handle_input_key(event)
      end

      # Renders the command palette as a vertically-stacked text representation: the search TextInput
      # row on line 1, and then the filtered List results (or "No commands found") on subsequent lines.
      # Returns a multiline string suitable for terminal rendering.
      def render
        [input.render, render_results].join("\n")
      end

      private

      attr_reader :height, :list

      # Delegates key handling entirely to the internal List widget, which manages up/down/home/end selection.
      # Returns whatever the List's handle_key returns (a Result or nil).
      def handle_list_key(event)
        list.handle_key(event)
      end

      # Passes the key event to the TextInput for cursor position and search text management.
      # If the input returns Result.handled, rebuilds the List so that filtering is re-evaluated
      # against the new input value. Returns the input's Result, or nil when it did not consume
      # the event.
      def handle_input_key(event)
        result = input.handle_key(event)
        @list = build_list if result&.handled?
        result
      end

      # Checks whether the given key is a List-navigation key (up/down/home/end). Returns true for those keys
      # so they can be dispatched via +handle_list_key+ rather than falling through to TextInput.
      def list_key?(key)
        %i[up down home end enter].include?(key)
      end

      # Renders the filtered results section below the search input. If no commands match the current filter text,
      # returns "No commands found"; otherwise renders the List widget's styled display string. Returns a single-line string.
      def render_results
        return "No commands found" if filtered_commands.empty?

        list.render
      end

      # Builds a new List from the currently filtered commands at the given selected_index height and label extractor.
      # The +selected_index+ parameter defaults to the last known value in +list+ to preserve scroll position across rebuilds.
      def build_list(selected_index: list&.selected_index || 0)
        List.new(items: filtered_commands, selected_index: selected_index, height: height, label: :label.to_proc, theme: theme)
      end

      # Returns the full commands array when input value is empty; otherwise the commands
      # fuzzy-matched against the typed value, best matches first (see FuzzyMatcher).
      def filtered_commands
        return commands if input.value.empty?

        FuzzyMatcher.filter(input.value, commands) { |command| command.label.to_s }
      end
    end
  end
end
