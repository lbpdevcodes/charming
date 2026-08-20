# frozen_string_literal: true

module DemoApp
  class LgController < ApplicationController
    layout false

    focus_ring :status, :commits, :files, :diff

    def show
      render :show, palette: command_palette
    end
  end
end
