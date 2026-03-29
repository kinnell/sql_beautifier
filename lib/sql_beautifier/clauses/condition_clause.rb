# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class ConditionClause < Base
      def call
        return "#{keyword_prefix}#{@value.strip}" unless multiple_conditions?

        formatted_conditions = Condition.format(@value, indent_width: SqlBeautifier.config_for(:keyword_column_width))
        formatted_conditions.sub(continuation_indent, keyword_prefix)
      end

      private

      def multiple_conditions?
        Tokenizer.split_top_level_conditions(@value).length > 1
      end
    end
  end
end
