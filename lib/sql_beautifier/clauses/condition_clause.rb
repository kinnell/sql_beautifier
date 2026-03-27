# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class ConditionClause < Base
      def call
        return "#{self.class::KEYWORD_PREFIX}#{@value.strip}" unless multiple_conditions?

        formatted_conditions = ConditionFormatter.format(@value, indent_width: Constants::KEYWORD_COLUMN_WIDTH)
        formatted_conditions.sub(Constants::LEADING_KEYWORD_INDENT_PATTERN, self.class::KEYWORD_PREFIX)
      end

      private

      def multiple_conditions?
        Tokenizer.split_top_level_conditions(@value).length > 1
      end
    end
  end
end
