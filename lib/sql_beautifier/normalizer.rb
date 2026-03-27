# frozen_string_literal: true

module SqlBeautifier
  class Normalizer
    SAFE_UNQUOTED_IDENTIFIER = %r{\A[[:lower:]_][[:lower:][:digit:]_]*\z}

    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      return unless @value.present?

      @source = @value.squish
      return unless @source.present?

      @output = +""
      @position = 0

      while @position < @source.length
        case current_character
        when "'"
          consume_string_literal!

        when '"'
          consume_quoted_identifier!

        else
          @output << current_character.downcase
          @position += 1
        end
      end

      @output
    end

    private

    def current_character
      @source[@position]
    end

    def consume_string_literal!
      @output << current_character
      @position += 1

      while @position < @source.length
        character = current_character
        @output << character

        if character == "'" && @source[@position + 1] == "'"
          @position += 1
          @output << current_character
        elsif character == "'"
          @position += 1
          return
        end

        @position += 1
      end
    end

    def consume_quoted_identifier!
      start_position = @position
      identifier = +""
      @position += 1

      while @position < @source.length
        character = current_character

        if character == '"' && @source[@position + 1] == '"'
          identifier << '"'
          @position += 2
        elsif character == '"'
          @position += 1
          @output << format_identifier(identifier)
          return
        else
          identifier << character
          @position += 1
        end
      end

      @position = start_position
      @output << current_character.downcase
      @position += 1
    end

    def format_identifier(identifier)
      lowercased = identifier.downcase

      if requires_quoting?(lowercased)
        "\"#{lowercased.gsub('"', '""')}\""
      else
        lowercased
      end
    end

    def requires_quoting?(identifier)
      identifier !~ SAFE_UNQUOTED_IDENTIFIER
    end
  end
end
