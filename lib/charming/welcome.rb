# frozen_string_literal: true

module Charming
  # Welcome is the built-in placeholder screen shown when an application defines no
  # routes yet — the TUI equivalent of Rails' welcome page. It lives in the gem and is
  # never copied into apps: defining any route in config/routes.rb replaces it.
  module Welcome
    # The fallback route the Runtime uses when the application has no routes.
    def self.route
      Router::Route.new(name: :root, controller_class: Controller, action: :show, title: "Welcome", params: {})
    end
  end
end
