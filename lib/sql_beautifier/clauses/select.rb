# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Select < Base
      KEYWORD = "select"
      DISTINCT_ON_PARENTHESIS_PATTERN = %r{distinct on\s*\(}
      DISTINCT_ON_PATTERN = %r{distinct on }
      LEADING_COMMA_PATTERN = %r{\A,\s*}

      def call
        prefix, remaining_columns = extract_prefix
        @expressions = parse_expressions(remaining_columns)

        return format_with_prefix(prefix) if prefix
        return keyword_line(@expressions.first.render) if @expressions.length == 1

        format_columns_list
      end

      private

      def parse_expressions(value)
        keyword_width = SqlBeautifier.config_for(:keyword_column_width)

        Tokenizer.split_by_top_level_commas(value).map do |column|
          formatted_column = CaseExpression.format_in_text(column, base_indent: keyword_width)
          Expression.parse(formatted_column)
        end
      end

      def keyword_line(text)
        "#{keyword_prefix}#{text.strip}"
      end

      def continuation_line(text)
        "#{continuation_indent}#{text.strip}"
      end

      def format_with_prefix(prefix)
        first_line = "#{keyword_prefix}#{prefix}"
        column_lines = @expressions.map do |expression|
          continuation_line(expression.render)
        end

        "#{first_line}\n#{column_lines.join(",\n")}"
      end

      def format_columns_list
        column_lines = @expressions.map do |expression|
          continuation_line(expression.render)
        end

        column_lines[0] = keyword_line(@expressions.first.render)

        column_lines.join(",\n")
      end

      def extract_prefix
        stripped_value = @value.strip

        if stripped_value.start_with?("distinct on ")
          extract_distinct_on_prefix(stripped_value)
        elsif stripped_value.start_with?("distinct ")
          remaining_columns = stripped_value.delete_prefix("distinct ").strip

          ["distinct", remaining_columns]
        else
          [nil, stripped_value]
        end
      end

      def extract_distinct_on_prefix(stripped_value)
        distinct_on_position = stripped_value.index(DISTINCT_ON_PARENTHESIS_PATTERN) || stripped_value.index(DISTINCT_ON_PATTERN)
        opening_parenthesis_position = stripped_value.index(Constants::OPEN_PARENTHESIS, distinct_on_position)
        return [nil, stripped_value] unless opening_parenthesis_position

        closing_parenthesis_position = Scanner.new(stripped_value).find_matching_parenthesis(opening_parenthesis_position)
        return [nil, stripped_value] unless closing_parenthesis_position

        prefix = stripped_value[0..closing_parenthesis_position]
        columns_text = stripped_value[(closing_parenthesis_position + 1)..]
        stripped_columns_text = columns_text.strip
        remaining_columns = stripped_columns_text.sub(LEADING_COMMA_PATTERN, "")

        [prefix, remaining_columns]
      end
    end
  end
end
