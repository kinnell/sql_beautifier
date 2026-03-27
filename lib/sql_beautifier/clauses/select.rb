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
        columns = Tokenizer.split_by_top_level_commas(remaining_columns)

        return format_with_prefix(prefix, columns) if prefix
        return keyword_line(columns.first) if columns.length == 1

        format_columns_list(columns)
      end

      private

      def keyword_line(column)
        "#{keyword_prefix}#{column.strip}"
      end

      def continuation_line(column)
        "#{continuation_indent}#{column.strip}"
      end

      def format_with_prefix(prefix, columns)
        first_line = "#{keyword_prefix}#{prefix}"
        column_lines = columns.map { |column| continuation_line(column) }

        "#{first_line}\n#{column_lines.join(",\n")}"
      end

      def format_columns_list(columns)
        column_lines = columns.map { |column| continuation_line(column) }
        column_lines[0] = keyword_line(columns.first)

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

        closing_parenthesis_position = Tokenizer.find_matching_parenthesis(stripped_value, opening_parenthesis_position)
        return [nil, stripped_value] unless closing_parenthesis_position

        prefix = stripped_value[0..closing_parenthesis_position]
        remaining_columns = stripped_value[(closing_parenthesis_position + 1)..].strip.sub(LEADING_COMMA_PATTERN, "")

        [prefix, remaining_columns]
      end
    end
  end
end
