# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class ConditionClause < Base
      def call
        keyword_width = SqlBeautifier.config_for(:keyword_column_width)
        formatted_value = CaseExpression.format_in_text(@value, base_indent: keyword_width)
        unwrapped_value = strip_wrapping_parentheses(formatted_value)
        unwrapped_value = Condition.unwrap_not_prefix_parens(unwrapped_value)

        unless multiple_conditions?(unwrapped_value)
          formatted_leaf = InList.format_in_text(unwrapped_value, base_indent: keyword_width)
          return "#{keyword_prefix}#{formatted_leaf}"
        end

        formatted_conditions = Condition.format(unwrapped_value, indent_width: keyword_width)
        formatted_conditions.sub(continuation_indent, keyword_prefix)
      end

      private

      def strip_wrapping_parentheses(text)
        output = text.strip
        output = Util.strip_outer_parentheses(output) while Tokenizer.outer_parentheses_wrap_all?(output)
        output
      end

      def multiple_conditions?(text)
        Tokenizer.split_top_level_conditions(text).length > 1
      end
    end
  end
end
