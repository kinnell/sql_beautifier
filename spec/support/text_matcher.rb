# frozen_string_literal: true

RSpec::Matchers.define :match_formatted_text do |expected|
  define_method(:expectation) do
    expected.chomp.tr("·", " ")
  end

  match do |actual|
    actual == expectation
  end

  failure_message do |actual|
    <<~TEXT
      EXPECTED:
      #{expectation.inspect}

      ACTUAL:
      #{actual.inspect}
    TEXT
  end
end

RSpec::Matchers.define :include_formatted_text do |expected|
  define_method(:expectation) do
    expected.chomp.tr("·", " ")
  end

  match do |actual|
    actual.include?(expectation)
  end

  failure_message do |actual|
    <<~TEXT
      EXPECTED:
      #{expectation.inspect}

      ACTUAL:
      #{actual.inspect}
    TEXT
  end
end
