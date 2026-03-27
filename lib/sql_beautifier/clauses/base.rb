# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class Base
      def self.call(value)
        new(value).call
      end

      def initialize(value)
        @value = value
      end

      private

      def keyword_prefix
        Util.keyword_padding(self.class::KEYWORD)
      end

      def continuation_indent
        Util.continuation_padding
      end
    end
  end
end
