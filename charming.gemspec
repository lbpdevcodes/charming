# frozen_string_literal: true

require_relative "lib/charming/version"

Gem::Specification.new do |spec|
  spec.name = "charming"
  spec.version = Charming::VERSION
  spec.authors = ["pando"]
  spec.email = ["pandorocks@proton.me"]

  spec.summary = "A Rails-inspired TUI framework for Ruby."
  spec.description = "Charming brings Rails-like application, routing, controller, and rendering " \
                     "conventions to Ruby terminal user interfaces."
  spec.homepage = "https://github.com/pandorocks/charming"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{exe,lib,sig}/**/*") + %w[LICENSE.txt README.md]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |file| File.basename(file) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel", "~> 8.1", ">= 8.1.2"
  spec.add_dependency "commonmarker", "~> 2.0"
  spec.add_dependency "logger", "~> 1.7"
  spec.add_dependency "rouge", "~> 5.0"
  spec.add_dependency "tty-reader", "~> 0.9"
  spec.add_dependency "unicode-display_width", "~> 2.6"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # Database support is opt-in: apps generated with `--database sqlite3` (or that run
  # `charming db:install`) declare activerecord + sqlite3 in their own gemspec.
end
