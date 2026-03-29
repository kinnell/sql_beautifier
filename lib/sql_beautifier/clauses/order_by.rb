# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class OrderBy < Base
      KEYWORD = "order by"

      def call
        expressions = parse_expressions(@value)
        expressions_output = expressions.map(&:render).join(", ")

        "#{keyword_prefix}#{expressions_output}"
      end

      private

      def parse_expressions(value)
        Tokenizer.split_by_top_level_commas(value).map do |item|
          SortExpression.parse(item)
        end
      end
    end
  end
end
