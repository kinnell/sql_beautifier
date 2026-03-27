# frozen_string_literal: true

module SqlBeautifier
  module Util
    module_function

    def whitespace(length)
      " " * length
    end

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

    def keyword_padding(keyword)
      formatted_keyword = format_keyword(keyword)
      padding_width = [SqlBeautifier.config_for(:keyword_column_width) - formatted_keyword.length, 1].max

      "#{formatted_keyword}#{whitespace(padding_width)}"
    end

    def continuation_padding
      whitespace(SqlBeautifier.config_for(:keyword_column_width))
    end

    def format_keyword(keyword)
      case SqlBeautifier.config_for(:keyword_case)
      when :upper
        keyword.upcase
      else
        keyword.downcase
      end
    end

    def format_table_name(name)
      case SqlBeautifier.config_for(:table_name_format)
      when :lowercase
        name.downcase
      else
        upper_pascal_case(name)
      end
    end
  end
end
