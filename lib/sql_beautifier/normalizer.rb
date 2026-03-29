# frozen_string_literal: true

module SqlBeautifier
  class Normalizer
    SAFE_UNQUOTED_IDENTIFIER = %r{\A[[:lower:]_][[:lower:][:digit:]_]*\z}

    def self.call(...)
      new(...).call
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

      @scanner = Scanner.new(@source)
      @output = +""

      until @scanner.finished?
        if @scanner.sentinel_at?
          @output << @scanner.consume_sentinel!
          next
        end

        case @scanner.current_char
        when Constants::SINGLE_QUOTE
          consume_string_literal!

        when Constants::DOUBLE_QUOTE
          consume_quoted_identifier!

        when Constants::WHITESPACE_CHARACTER_REGEX
          collapse_whitespace!

        else
          @output << @scanner.current_char.downcase
          @scanner.advance!
        end
      end

      @output
    end

    private

    def collapse_whitespace!
      @output << " "
      @scanner.advance!
      @scanner.skip_whitespace!
    end

    def consume_string_literal!
      @output << @scanner.current_char
      @scanner.advance!

      until @scanner.finished?
        character = @scanner.current_char
        @output << character

        if character == Constants::SINGLE_QUOTE && @scanner.peek == Constants::SINGLE_QUOTE
          @scanner.advance!
          @output << @scanner.current_char
        elsif character == Constants::SINGLE_QUOTE
          @scanner.advance!
          return
        end

        @scanner.advance!
      end
    end

    def consume_quoted_identifier!
      start_position = @scanner.position
      identifier = +""
      @scanner.advance!

      until @scanner.finished?
        character = @scanner.current_char

        if character == Constants::DOUBLE_QUOTE && @scanner.peek == Constants::DOUBLE_QUOTE
          identifier << Constants::DOUBLE_QUOTE
          @scanner.advance!(2)
        elsif character == Constants::DOUBLE_QUOTE
          @scanner.advance!
          @output << format_identifier(identifier)
          return
        else
          identifier << character
          @scanner.advance!
        end
      end

      @scanner.advance!(start_position - @scanner.position + 1) if start_position != @scanner.position
      @output << @source[start_position].downcase
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
