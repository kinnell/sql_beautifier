# frozen_string_literal: true

module SqlBeautifier
  module Util
    module_function

    def upper_pascal_case(name)
      name.split("_").map(&:capitalize).join("_")
    end

    def first_word(text)
      text.strip.split(Constants::WHITESPACE_REGEX).first
    end

    def strip_outer_parentheses(text)
      stripped_text = text.strip
      return stripped_text unless stripped_text.start_with?(Constants::OPEN_PARENTHESIS) && stripped_text.end_with?(Constants::CLOSE_PARENTHESIS)

      stripped_text[1...-1].strip
    end

    def double_quote_string(value)
      return if value.nil?

      "#{Constants::DOUBLE_QUOTE}#{value}#{Constants::DOUBLE_QUOTE}"
    end

    def escape_double_quote(value)
      return if value.nil?

      value.gsub(Constants::DOUBLE_QUOTE, Constants::ESCAPED_DOUBLE_QUOTE)
    end
  end
end
