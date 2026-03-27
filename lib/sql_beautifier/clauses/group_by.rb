# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class GroupBy < Base
      KEYWORD = "group by"

      def call
        "#{keyword_prefix}#{@value.strip}"
      end
    end
  end
end
