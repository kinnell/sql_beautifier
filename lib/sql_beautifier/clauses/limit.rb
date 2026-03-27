# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Limit < Base
      KEYWORD_PREFIX = "limit "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
