# frozen_string_literal: true

module Journal
  class StatsController < ApplicationController
    EXPORT_PATH = "tmp/journal_export.md"

    focus_ring :content, :sidebar

    key "x", :start_export
    timer :export_spinner, every: 0.1, action: :advance_spinner

    on_task :export, action: :export_finished
    on_task_progress :export, action: :export_progressed

    def show
      render :show, stats: stats, mood_counts: mood_counts, total: Entry.count,
        streak: writing_streak, palette: command_palette
    end

    # Kicks off the async export with per-entry progress reporting.
    def start_export
      return show if stats.exporting

      entries = Entry.recent_first.to_a
      stats.exporting = true
      stats.export_current = 0
      stats.export_total = entries.length

      # Data goes in via `with:` (deep-frozen at submit time); results come out as
      # the block value and land in export_finished on the loop thread.
      run_task(:export, with: {entries: entries}) do |ctx|
        entries = ctx[:entries]
        path = File.expand_path(EXPORT_PATH, Dir.pwd)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "w") do |file|
          entries.each_with_index do |entry, index|
            file.puts "# #{entry.title}\n\n_#{entry.created_at.strftime("%Y-%m-%d")} · #{entry.mood}_\n\n#{entry.body}\n\n---\n"
            ctx.report(index + 1, of: entries.length, message: entry.title)
            sleep 0.15 # visible progress in the live demo
          end
        end
        entries.length
      end
      show
    end

    def export_progressed
      stats.export_current = event.current
      stats.export_total = event.total
      show
    end

    def export_finished
      stats.exporting = false
      if event.error?
        show_toast("Export failed: #{event.error.message}", kind: :error)
      else
        show_toast("Exported #{event.value} entries to #{EXPORT_PATH}")
      end
      show
    end

    # Drives the activity indicator while an export runs; renders nothing otherwise.
    def advance_spinner
      return unless stats.exporting

      stats.activity_index += 1
      show
    end

    def status_hints
      [["x", "export"], *super]
    end

    private

    def stats
      state(:stats, StatsState)
    end

    def mood_counts
      Entry::MOODS.to_h { |mood| [mood, Entry.where(mood: mood).count] }
    end

    # Consecutive days (ending today or yesterday) with at least one entry.
    def writing_streak
      days = Entry.pluck(:created_at).map(&:to_date).uniq.sort.reverse
      streak = 0
      expected = Date.today
      days.each do |day|
        expected = day if streak.zero? && day == expected - 1
        break unless day == expected

        streak += 1
        expected = day - 1
      end
      streak
    end
  end
end
