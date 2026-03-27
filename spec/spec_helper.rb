# frozen_string_literal: true

require "pathname"

require "sql_beautifier"

SPEC_PATH = Pathname.new(__dir__).freeze
SPEC_PATH.glob("support/**/*.rb").each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.filter_run_when_matching :focus
  config.pattern = "**/*.spec.rb"
  config.after { SqlBeautifier.reset_configuration! }
end
