# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class OrderBy < Base
      KEYWORD = "order by"

      def call
        "#{keyword_prefix}#{@value.strip}"
      end
    end
  end
end
