# frozen_string_literal: true

module DemoApp
  class ApplicationController < Charming::Controller
    layout Layouts::ApplicationLayout
    focus_ring :sidebar, :content

    key "ctrl+p", :open_command_palette, scope: :global
    key "q", :quit, scope: :global

    command "Home" do
      navigate :root
    end

    command "Theme", :open_theme_palette

    command "LG Layout" do
      navigate :lg
    end

    command "Image" do
      navigate :image
    end

    command "Charts" do
      navigate :charts
    end

    command "Close palette", :close_command_palette
    command "Quit app", :quit
  end
end
