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

      @source = strip_comments(@source)
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

    def strip_comments(sql)
      output = +""
      position = 0
      in_single_quoted_string = false
      in_double_quoted_identifier = false

      while position < sql.length
        character = sql[position]

        if in_single_quoted_string
          output << character

          if character == Constants::SINGLE_QUOTE && sql[position + 1] == Constants::SINGLE_QUOTE
            position += 1
            output << sql[position]
          elsif character == Constants::SINGLE_QUOTE
            in_single_quoted_string = false
          end

          position += 1
          next
        end

        if in_double_quoted_identifier
          output << character

          if character == Constants::DOUBLE_QUOTE && sql[position + 1] == Constants::DOUBLE_QUOTE
            position += 1
            output << sql[position]
          elsif character == Constants::DOUBLE_QUOTE
            in_double_quoted_identifier = false
          end

          position += 1
          next
        end

        if character == Constants::SINGLE_QUOTE
          in_single_quoted_string = true
          output << character
          position += 1
        elsif character == Constants::DOUBLE_QUOTE
          in_double_quoted_identifier = true
          output << character
          position += 1
        elsif character == "-" && sql[position + 1] == "-"
          position += 2
          position += 1 while position < sql.length && sql[position] != "\n"
        elsif character == "/" && sql[position + 1] == "*"
          output << " " unless output.empty? || output[-1] =~ Constants::WHITESPACE_CHARACTER_REGEX
          position += 2
          position += 1 while position < sql.length && !(sql[position] == "*" && sql[position + 1] == "/")
          position += 2 if position < sql.length
        else
          output << character
          position += 1
        end
      end

      output
    end
  end
end
