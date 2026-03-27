# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Where < Base
      KEYWORD_PREFIX = "where   "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
