# frozen_string_literal: true

RSpec.describe Charming::Internal::Inflections do
  subject(:inflections) { described_class }

  describe ".camelize" do
    it "capitalizes a single lowercase word" do
      expect(inflections.camelize("home")).to eq("Home")
    end

    it "converts snake_case to CamelCase" do
      expect(inflections.camelize("weather_report")).to eq("WeatherReport")
      expect(inflections.camelize("user_settings")).to eq("UserSettings")
    end

    it "converts slashes to namespace separators" do
      expect(inflections.camelize("admin/user_settings")).to eq("Admin::UserSettings")
    end
  end

  describe ".underscore" do
    it "converts CamelCase to snake_case" do
      expect(inflections.underscore("HomeController")).to eq("home_controller")
    end

    it "places a boundary between an acronym run and a capitalized word" do
      expect(inflections.underscore("HTMLTidy")).to eq("html_tidy")
    end

    it "converts namespace separators to slashes" do
      expect(inflections.underscore("MyApp::HomeController")).to eq("my_app/home_controller")
    end
  end

  describe ".demodulize" do
    it "returns the trailing constant name" do
      expect(inflections.demodulize("MyApp::HomeController")).to eq("HomeController")
    end

    it "returns the input unchanged when there is no namespace" do
      expect(inflections.demodulize("HomeController")).to eq("HomeController")
    end
  end

  describe ".deconstantize" do
    it "removes the trailing constant" do
      expect(inflections.deconstantize("MyApp::Application")).to eq("MyApp")
    end

    it "returns an empty string for a top-level name" do
      expect(inflections.deconstantize("Application")).to eq("")
    end
  end

  describe ".constantize" do
    it "resolves a nested constant path" do
      expect(inflections.constantize("Charming::Router")).to eq(Charming::Router)
    end

    it "raises NameError for an unknown path" do
      expect { inflections.constantize("Charming::NoSuchThing") }.to raise_error(NameError)
    end
  end

  describe "round-tripping" do
    %w[home weather_report user_settings projects list].each do |snake_name|
      it "underscore(camelize(#{snake_name})) returns #{snake_name}" do
        expect(inflections.underscore(inflections.camelize(snake_name))).to eq(snake_name)
      end
    end
  end

  describe ".humanize" do
    it "capitalizes the first letter of a single word" do
      expect(inflections.humanize("email")).to eq("Email")
    end

    it "replaces underscores with spaces" do
      expect(inflections.humanize("user_name")).to eq("User name")
    end

    it "strips a trailing _id" do
      expect(inflections.humanize("author_id")).to eq("Author")
    end
  end

  describe ".pluralize" do
    it "appends s to a regular word" do
      expect(inflections.pluralize("user")).to eq("users")
    end

    it "converts a consonant-plus-y ending to ies" do
      expect(inflections.pluralize("category")).to eq("categories")
    end

    it "appends es to words ending in s, x, ch, or sh" do
      expect(inflections.pluralize("class")).to eq("classes")
      expect(inflections.pluralize("box")).to eq("boxes")
      expect(inflections.pluralize("match")).to eq("matches")
      expect(inflections.pluralize("wish")).to eq("wishes")
    end

    it "pluralizes the last word of a snake_case compound" do
      expect(inflections.pluralize("line_item")).to eq("line_items")
    end

    it "applies irregular forms" do
      expect(inflections.pluralize("person")).to eq("people")
      expect(inflections.pluralize("child")).to eq("children")
    end

    it "leaves uncountable words unchanged" do
      expect(inflections.pluralize("equipment")).to eq("equipment")
    end
  end
end
