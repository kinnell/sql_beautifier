# frozen_string_literal: true

require "bundler"

namespace :gem_tasks do
  Bundler::GemHelper.install_tasks
end

task default: :ci

desc "Run continuous integration suite"
task :ci do
  exec "./bin/ci"
end

desc "Run tests"
task :test do
  exec "bundle exec rspec"
end

desc "Run ruby linter"
task :lint do
  exec "bundle exec rubocop"
end

desc "Start an IRB console"
task :console do
  require "irb"
  require "bundler/setup"

  require_relative "lib/sql_beautifier"
  puts "Loading sql_beautifier v#{SqlBeautifier::VERSION}"

  ARGV.clear
  IRB.start
end
