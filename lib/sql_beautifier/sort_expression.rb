# frozen_string_literal: true

module SqlBeautifier
  class SortExpression < Base
    DIRECTION_PATTERN = %r{\s+(asc|desc)(?:\s+(nulls\s+(?:first|last)))?\z}i
    NULLS_ONLY_PATTERN = %r{\s+(nulls\s+(?:first|last))\z}i

    option :expression
    option :direction, default: -> {}
    option :nulls, default: -> {}

    def self.parse(text)
      stripped = text.strip

      direction_match = stripped.match(DIRECTION_PATTERN)
      if direction_match
        expression = stripped[0...direction_match.begin(0)].strip
        direction = direction_match[1].downcase
        nulls = direction_match[2]&.downcase&.squeeze(" ")
        return new(expression: expression, direction: direction, nulls: nulls)
      end

      nulls_match = stripped.match(NULLS_ONLY_PATTERN)
      if nulls_match
        expression = stripped[0...nulls_match.begin(0)].strip
        return new(expression: expression, nulls: nulls_match[1].downcase.squeeze(" "))
      end

      new(expression: stripped)
    end

    def render
      parts = [@expression]
      parts << @direction if @direction
      parts << @nulls if @nulls
      parts.join(" ")
    end
  end
end
