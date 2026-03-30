# frozen_string_literal: true

module SqlBeautifier
  module DmlRendering
    private

    def render_where
      keyword_column_width = SqlBeautifier.config_for(:keyword_column_width)
      conditions = Condition.parse_all(@where_clause)

      formatted_where_text = begin
        if conditions.length <= 1 && conditions.first&.leaf?
          "\n#{Util.keyword_padding('where')}#{@where_clause.strip}"
        else
          formatted_conditions = Condition.render_all(conditions, indent_width: keyword_column_width)
          "\n#{formatted_conditions.sub(Util.continuation_padding, Util.keyword_padding('where'))}"
        end
      end

      Query.format_subqueries_in_text(formatted_where_text, depth: @depth)
    end

    def render_returning
      "\n#{Util.keyword_padding('returning')}#{@returning_clause}"
    end
  end
end
