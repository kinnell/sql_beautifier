# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class From < Base
      KEYWORD_PREFIX = "from    "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
