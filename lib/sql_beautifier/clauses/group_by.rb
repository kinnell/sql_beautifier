# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class GroupBy < Base
      KEYWORD_PREFIX = "group by "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
