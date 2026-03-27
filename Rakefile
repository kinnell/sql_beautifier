# frozen_string_literal: true

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
