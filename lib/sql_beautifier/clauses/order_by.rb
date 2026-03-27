# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class OrderBy < Base
      KEYWORD_PREFIX = "order by "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
