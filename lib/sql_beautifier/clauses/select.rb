# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Select < Base
      KEYWORD_PREFIX = "select  "
      CONTINUATION_INDENT = "        "

      def call
        columns = Tokenizer.split_by_top_level_commas(@value)
        return "#{KEYWORD_PREFIX}#{columns.first.strip}" if columns.length == 1

        column_lines = columns.map { |column| "#{CONTINUATION_INDENT}#{column.strip}" }
        column_lines[0] = "#{KEYWORD_PREFIX}#{columns.first.strip}"

        column_lines.join(",\n")
      end
    end
  end
end
