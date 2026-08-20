# frozen_string_literal: true

module Charming
  module Internal
    # String inflection helpers covering exactly what Charming needs, with
    # ActiveSupport-compatible semantics for the inputs Charming produces
    # (snake_case identifiers and "A::B" constant paths). Replaces the former
    # ActiveSupport::Inflector dependency. `pluralize` implements a deliberate
    # subset of English rules — enough for conventional resource names — not
    # ActiveSupport's full inflection table.
    module Inflections
      module_function

      # "weather_report" → "WeatherReport"; "admin/users" → "Admin::Users".
      def camelize(term)
        string = term.to_s.sub(/\A[a-z\d]*/, &:capitalize)
        string.gsub(%r{(?:_|(/))([a-z\d]*)}i) { "#{Regexp.last_match(1) && "::"}#{Regexp.last_match(2).capitalize}" }
      end

      # "HomeController" → "home_controller"; "MyApp::Home" → "my_app/home";
      # acronym runs get a boundary before a capitalized word ("HTMLTidy" → "html_tidy").
      def underscore(camel_cased_word)
        word = camel_cased_word.to_s.gsub("::", "/")
        word.gsub!(/([A-Z\d]+)(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { "#{Regexp.last_match(1) || Regexp.last_match(2)}_" }
        word.tr!("-", "_")
        word.downcase!
        word
      end

      # "MyApp::HomeController" → "HomeController".
      def demodulize(path)
        path.to_s.split("::").last
      end

      # "MyApp::Application" → "MyApp"; "Application" → "".
      def deconstantize(path)
        path.to_s[0, path.to_s.rindex("::") || 0]
      end

      # "Charming::Router" → Charming::Router. Raises NameError on a miss.
      def constantize(name)
        Object.const_get(name)
      end

      # "user_name" → "User name"; "author_id" → "Author". Assumes snake_case input.
      def humanize(lower_case_and_underscored_word)
        result = lower_case_and_underscored_word.to_s.sub(/_id\z/, "").tr("_", " ")
        result.sub(/\A\w/, &:upcase)
      end

      # "category" → "categories"; "person" → "people". A subset of English
      # rules covering conventional resource names; exotic words may need the
      # generated migration renamed by hand.
      def pluralize(word)
        result = word.to_s.dup
        return result if UNCOUNTABLE.include?(result)

        irregular = IRREGULAR_FORMS[result.split("_").last]
        return result.sub(/[^_]+\z/, irregular) if irregular

        PLURAL_RULES.each do |pattern, replacement|
          return result.sub(pattern, replacement) if result.match?(pattern)
        end
        result
      end

      IRREGULAR_FORMS = {
        "child" => "children",
        "man" => "men",
        "mouse" => "mice",
        "person" => "people",
        "sex" => "sexes",
        "woman" => "women"
      }.freeze

      UNCOUNTABLE = %w[equipment information money rice series sheep species].freeze

      # Ordered: the first matching rule wins. Mirrors the head of
      # ActiveSupport's plural rule list for the inputs generators produce.
      PLURAL_RULES = [
        [/(quiz)\z/, '\1zes'],
        [/(matr|vert|ind)(ix|ex)\z/, '\1ices'],
        [/(x|ch|ss|sh)\z/, '\1es'],
        [/([^aeiouy]|qu)y\z/, '\1ies'],
        [/sis\z/, "ses"],
        [/([ti])um\z/, '\1a'],
        [/(buffal|tomat|potat|her)o\z/, '\1oes'],
        [/s\z/, "s"],
        [/\z/, "s"]
      ].freeze
    end
  end
end
