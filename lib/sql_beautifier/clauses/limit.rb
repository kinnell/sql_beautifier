# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Limit < Base
      KEYWORD = "limit"

      def call
        "#{keyword_prefix}#{@value.strip}"
      end

      private

      def keyword_prefix
        "#{Util.format_keyword(KEYWORD)} "
      end
    end
  end
end
