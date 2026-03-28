# frozen_string_literal: true

RSpec::Matchers.define :match_formatted_text do |expected_text|
  match do |actual|
    actual == expected_text.chomp.tr("·", " ")
  end

  failure_message do |actual|
    "expected #{actual.inspect} to match #{expected_text.inspect}"
  end
end

RSpec::Matchers.define :include_formatted_text do |expected_text|
  match do |actual|
    actual.include?(expected_text.chomp.tr("·", " "))
  end

  failure_message do |actual|
    "expected #{actual.inspect} to include #{expected_text.inspect}"
  end
end
