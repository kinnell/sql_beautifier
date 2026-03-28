# frozen_string_literal: true

require_relative "lib/sql_beautifier/version"

Gem::Specification.new do |spec|
  spec.name = "sql_beautifier"
  spec.version = SqlBeautifier::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.authors = ["Kinnell Shah"]
  spec.email = ["kinnell@gmail.com"]

  spec.summary = "Opinionated PostgreSQL SQL formatter"
  spec.description = <<~TEXT
    Formats raw SQL into a clean, consistent style with lowercase keywords, padded keyword alignment, and vertically separated clauses.
  TEXT

  spec.homepage = "https://github.com/kinnell/sql_beautifier"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["github_repo"] = "https://github.com/kinnell/sql_beautifier"
  spec.metadata["source_code_uri"] = "https://github.com/kinnell/sql_beautifier"
  spec.metadata["changelog_uri"] = "https://github.com/kinnell/sql_beautifier/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/kinnell/sql_beautifier/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "*.md"]

  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")
  spec.required_rubygems_version = Gem::Requirement.new(">= 2.0")

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "dry-initializer", ">= 3.2"
  spec.add_dependency "dry-types", ">= 1.9"
end
