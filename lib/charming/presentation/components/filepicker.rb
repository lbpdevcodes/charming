# frozen_string_literal: true

module Charming
  module Components
    # Filepicker is a directory browser built on List. Enter descends into the
    # highlighted directory or returns `Result.selected(absolute_path)` for a file;
    # Backspace (or the "../" entry) goes up, never above the configured root.
    # Dotfiles are hidden until `toggle_hidden`.
    class Filepicker < Component
      PARENT_ENTRY = "../"

      # The directory currently being browsed.
      attr_reader :current_dir

      # *root* is the starting directory and the upper boundary for navigation.
      # *show_hidden* includes dotfiles from the start. *height* windows the
      # listing like List's height.
      def initialize(root: Dir.pwd, show_hidden: false, height: nil, theme: nil, keymap: :vim)
        super(theme: theme)
        @root = File.expand_path(root)
        @current_dir = @root
        @show_hidden = show_hidden
        @height = height
        @keymap = keymap
        rebuild_list
      end

      # The display entries for the current directory: an optional parent entry,
      # then directories ("name/") before files, alphabetically.
      def entries
        list.items
      end

      # Handles navigation: Enter descends/selects, Backspace ascends, and all
      # other keys delegate to the underlying List.
      def handle_key(event)
        case Charming.key_of(event)
        when :enter then activate(list.selected_item)
        when :backspace then ascend
        else list.handle_key(event)
        end
      end

      # Shows or hides dotfiles, refreshing the listing. Returns self.
      def toggle_hidden
        @show_hidden = !@show_hidden
        rebuild_list
        self
      end

      # Renders the current directory's listing via the underlying List.
      def render
        list.render
      end

      private

      attr_reader :list

      # Descends into directories, returns files as a selection.
      def activate(entry)
        return nil unless entry
        return ascend if entry == PARENT_ENTRY
        return descend(entry.delete_suffix("/")) if entry.end_with?("/")

        Result.selected(File.join(current_dir, entry))
      end

      # Enters *name* under the current directory.
      def descend(name)
        @current_dir = File.join(current_dir, name)
        rebuild_list
        Result.handled
      end

      # Moves to the parent directory, unless already at the root.
      def ascend
        return nil if current_dir == @root

        @current_dir = File.dirname(current_dir)
        rebuild_list
        Result.handled
      end

      # Builds a fresh List over the current directory's entries.
      def rebuild_list
        @list = List.new(items: directory_entries, height: @height, theme: theme, keymap: @keymap)
      end

      # Reads the current directory: parent entry (when below root), then
      # directories before files, each group alphabetical, dotfiles filtered.
      def directory_entries
        names = Dir.children(current_dir).sort
        names = names.reject { |name| name.start_with?(".") } unless @show_hidden
        directories, files = names.partition { |name| File.directory?(File.join(current_dir, name)) }
        parent = (current_dir == @root) ? [] : [PARENT_ENTRY]
        parent + directories.map { |name| "#{name}/" } + files
      end
    end
  end
end
