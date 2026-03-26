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
    end
  end
end
