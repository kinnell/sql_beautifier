# frozen_string_literal: true

module SqlBeautifier
  class Expression < Base
    option :definition
    option :alias_name, default: -> {}

    def self.parse(text)
      stripped = text.strip
      alias_position = find_top_level_as(stripped)

      if alias_position
        definition = stripped[0...alias_position].strip
        alias_name = stripped[(alias_position + 3)..].strip
        new(definition: definition, alias_name: alias_name)
      else
        new(definition: stripped)
      end
    end

    def self.find_top_level_as(text)
      scanner = Scanner.new(text)

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        return scanner.position if scanner.top_level? && scanner.keyword_at?("as")

        scanner.advance!
      end

      nil
    end

    def render
      return @definition unless @alias_name

      "#{@definition} as #{@alias_name}"
    end
  end
end
