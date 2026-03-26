# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Having < Base
      KEYWORD_PREFIX = "having  "

      def call
        "#{KEYWORD_PREFIX}#{@value.strip}"
      end
    end
  end
end
