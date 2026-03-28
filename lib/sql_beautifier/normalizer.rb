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

      @source = @value.strip
      return unless @source.present?

      @source = strip_trailing_semicolons(@source)
      @source = @source.strip
      return unless @source.present?

      @output = +""
      @position = 0

      while @position < @source.length
        case current_character
        when Constants::SINGLE_QUOTE
          consume_string_literal!

        when Constants::DOUBLE_QUOTE
          consume_quoted_identifier!

        when "/"
          if sentinel_at_position?
            consume_sentinel!
          else
            @output << current_character.downcase
            @position += 1
          end

        when Constants::WHITESPACE_CHARACTER_REGEX
          collapse_whitespace!

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

    def sentinel_at_position?
      @source[@position, CommentStripper::SENTINEL_PREFIX.length] == CommentStripper::SENTINEL_PREFIX
    end

    def consume_sentinel!
      sentinel_end = @source.index("*/", @position + CommentStripper::SENTINEL_PREFIX.length)

      unless sentinel_end
        @output << current_character.downcase
        @position += 1
        return
      end

      end_position = sentinel_end + 2
      @output << @source[@position...end_position]
      @position = end_position
    end

    def collapse_whitespace!
      @output << " "
      @position += 1
      @position += 1 while @position < @source.length && @source[@position] =~ Constants::WHITESPACE_CHARACTER_REGEX
    end

    def consume_string_literal!
      @output << current_character
      @position += 1

      while @position < @source.length
        character = current_character
        @output << character

        if character == Constants::SINGLE_QUOTE && @source[@position + 1] == Constants::SINGLE_QUOTE
          @position += 1
          @output << current_character
        elsif character == Constants::SINGLE_QUOTE
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

        if character == Constants::DOUBLE_QUOTE && @source[@position + 1] == Constants::DOUBLE_QUOTE
          identifier << Constants::DOUBLE_QUOTE
          @position += 2
        elsif character == Constants::DOUBLE_QUOTE
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
      downcased_identifier = identifier.downcase
      return downcased_identifier unless requires_quoting?(downcased_identifier)

      escaped_identifier = Util.escape_double_quote(downcased_identifier)
      Util.double_quote_string(escaped_identifier)
    end

    def requires_quoting?(identifier)
      identifier !~ SAFE_UNQUOTED_IDENTIFIER
    end

    def strip_trailing_semicolons(sql)
      sql.sub(%r{;[[:space:]]*\z}, "")
    end
  end
end
