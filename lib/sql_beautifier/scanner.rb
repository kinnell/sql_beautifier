# frozen_string_literal: true

module SqlBeautifier
  class Scanner
    IDENTIFIER_CHARACTER = %r{[[:alnum:]_$]}
    SENTINEL_MAX_LOOKBACK = 20

    attr_reader :source
    attr_reader :position
    attr_reader :parenthesis_depth

    def initialize(source, position: 0)
      @source = source
      @position = position
      @in_single_quote = false
      @in_double_quote = false
      @parenthesis_depth = 0
    end

    def finished?
      @position >= @source.length
    end

    def current_char
      @source[@position]
    end

    def peek(offset = 1)
      @source[@position + offset]
    end

    def top_level?
      @parenthesis_depth.zero? && !@in_single_quote && !@in_double_quote
    end

    def in_single_quote?
      @in_single_quote
    end

    def in_double_quote?
      @in_double_quote
    end

    def in_quoted_context?
      @in_single_quote || @in_double_quote
    end

    def advance!(count = 1)
      @position += count
    end

    def enter_single_quote!
      @in_single_quote = true
      @position += 1
    end

    def enter_double_quote!
      @in_double_quote = true
      @position += 1
    end

    def increment_depth!
      @parenthesis_depth += 1
    end

    def decrement_depth!
      @parenthesis_depth = [@parenthesis_depth - 1, 0].max
    end

    def consume_single_quoted_string!
      start = @position
      @position += 1

      while @position < @source.length
        if @source[@position] == Constants::SINGLE_QUOTE && @source[@position + 1] == Constants::SINGLE_QUOTE
          @position += 2
        elsif @source[@position] == Constants::SINGLE_QUOTE
          @position += 1
          return @source[start...@position]
        else
          @position += 1
        end
      end

      @source[start...@position]
    end

    def consume_double_quoted_identifier!
      start = @position
      @position += 1

      while @position < @source.length
        if @source[@position] == Constants::DOUBLE_QUOTE && @source[@position + 1] == Constants::DOUBLE_QUOTE
          @position += 2
        elsif @source[@position] == Constants::DOUBLE_QUOTE
          @position += 1
          return @source[start...@position]
        else
          @position += 1
        end
      end

      @source[start...@position]
    end

    def consume_sentinel!
      start = @position
      end_position = sentinel_end_position
      @position = end_position

      @source[start...end_position]
    end

    def consume_dollar_quoted_string!(delimiter)
      start = @position
      @position += delimiter.length

      while @position < @source.length
        if @source[@position, delimiter.length] == delimiter
          @position += delimiter.length
          return @source[start...@position]
        end

        @position += 1
      end

      @source[start...@position]
    end

    def skip_single_quoted_string!
      @position += 1

      while @position < @source.length
        if @source[@position] == Constants::SINGLE_QUOTE && @source[@position + 1] == Constants::SINGLE_QUOTE
          @position += 2
        elsif @source[@position] == Constants::SINGLE_QUOTE
          @position += 1
          return
        else
          @position += 1
        end
      end
    end

    def skip_double_quoted_identifier!
      @position += 1

      while @position < @source.length
        if @source[@position] == Constants::DOUBLE_QUOTE && @source[@position + 1] == Constants::DOUBLE_QUOTE
          @position += 2
        elsif @source[@position] == Constants::DOUBLE_QUOTE
          @position += 1
          return
        else
          @position += 1
        end
      end
    end

    def skip_sentinel!
      @position = sentinel_end_position
    end

    def skip_dollar_quoted_string!(delimiter)
      @position += delimiter.length

      while @position < @source.length
        if @source[@position, delimiter.length] == delimiter
          @position += delimiter.length
          return
        end

        @position += 1
      end
    end

    def scan_quoted_or_sentinel!
      return consume_sentinel! if sentinel_at?

      delimiter = dollar_quote_delimiter_at
      return consume_dollar_quoted_string!(delimiter) if delimiter

      case current_char
      when Constants::SINGLE_QUOTE
        consume_single_quoted_string!
      when Constants::DOUBLE_QUOTE
        consume_double_quoted_identifier!
      end
    end

    def skip_quoted_or_sentinel!
      if @in_single_quote
        advance_through_single_quote!
        return true
      end

      if @in_double_quote
        advance_through_double_quote!
        return true
      end

      if sentinel_at?
        skip_sentinel!
        return true
      end

      delimiter = dollar_quote_delimiter_at
      if delimiter
        skip_dollar_quoted_string!(delimiter)
        return true
      end

      false
    end

    def advance_through_single_quote!
      if @source[@position] == Constants::SINGLE_QUOTE && @source[@position + 1] == Constants::SINGLE_QUOTE
        @position += 2
      elsif @source[@position] == Constants::SINGLE_QUOTE
        @in_single_quote = false
        @position += 1
      else
        @position += 1
      end
    end

    def advance_through_double_quote!
      if @source[@position] == Constants::DOUBLE_QUOTE && @source[@position + 1] == Constants::DOUBLE_QUOTE
        @position += 2
      elsif @source[@position] == Constants::DOUBLE_QUOTE
        @in_double_quote = false
        @position += 1
      else
        @position += 1
      end
    end

    def sentinel_at?(at_position = @position)
      @source[at_position, CommentParser::SENTINEL_PREFIX.length] == CommentParser::SENTINEL_PREFIX
    end

    def sentinel_end_position(from_position = @position)
      closing = @source.index(CommentParser::SENTINEL_SUFFIX, from_position + CommentParser::SENTINEL_PREFIX.length)
      return from_position + 1 unless closing

      closing + CommentParser::SENTINEL_SUFFIX.length
    end

    def inside_sentinel?(at_position)
      search_start = [at_position - SENTINEL_MAX_LOOKBACK, 0].max
      prefix_position = @source.rindex(CommentParser::SENTINEL_PREFIX, at_position)
      return false unless prefix_position && prefix_position >= search_start

      at_position < sentinel_end_position(prefix_position)
    end

    def dollar_quote_delimiter_at(at_position = @position)
      return "$$" if @source[at_position, 2] == "$$"
      return unless @source[at_position] == "$"

      closing_dollar_position = @source.index("$", at_position + 1)
      return unless closing_dollar_position

      delimiter = @source[at_position..closing_dollar_position]
      tag = delimiter[1..-2]
      return unless tag.match?(%r{\A[[:alpha:]_][[:alnum:]_]*\z})

      delimiter
    end

    def keyword_at?(keyword, at_position = @position)
      return false unless @source[at_position, keyword.length]&.downcase == keyword

      previous_character = character_before(at_position)
      next_character = character_after(at_position, keyword.length)

      word_boundary?(previous_character) && word_boundary?(next_character)
    end

    def word_boundary?(character)
      character.nil? || character !~ IDENTIFIER_CHARACTER
    end

    def character_before(at_position = @position)
      return nil if at_position.zero?

      @source[at_position - 1]
    end

    def character_after(at_position = @position, offset = 1)
      target = at_position + offset
      return nil if target >= @source.length

      @source[target]
    end

    def escaped_single_quote?(at_position = @position)
      @source[at_position] == Constants::SINGLE_QUOTE && @source[at_position + 1] == Constants::SINGLE_QUOTE
    end

    def escaped_double_quote?(at_position = @position)
      @source[at_position] == Constants::DOUBLE_QUOTE && @source[at_position + 1] == Constants::DOUBLE_QUOTE
    end

    def skip_whitespace!
      @position += 1 while @position < @source.length && @source[@position] =~ Constants::WHITESPACE_CHARACTER_REGEX
    end

    def skip_past_keyword!(keyword)
      @position += keyword.length
      skip_whitespace!
    end

    def read_identifier!
      skip_whitespace!
      return nil if finished?

      if current_char == Constants::DOUBLE_QUOTE
        read_quoted_identifier!
      else
        read_unquoted_identifier!
      end
    end

    def find_matching_parenthesis(opening_position)
      local_depth = 0
      scan_position = opening_position

      while scan_position < @source.length
        character = @source[scan_position]

        if @source[scan_position] == Constants::SINGLE_QUOTE
          scan_position += 1
          while scan_position < @source.length
            if @source[scan_position] == Constants::SINGLE_QUOTE && @source[scan_position + 1] == Constants::SINGLE_QUOTE
              scan_position += 2
            elsif @source[scan_position] == Constants::SINGLE_QUOTE
              scan_position += 1
              break
            else
              scan_position += 1
            end
          end
          next
        end

        if character == Constants::DOUBLE_QUOTE
          scan_position += 1
          while scan_position < @source.length
            if @source[scan_position] == Constants::DOUBLE_QUOTE && @source[scan_position + 1] == Constants::DOUBLE_QUOTE
              scan_position += 2
            elsif @source[scan_position] == Constants::DOUBLE_QUOTE
              scan_position += 1
              break
            else
              scan_position += 1
            end
          end
          next
        end

        if sentinel_at?(scan_position)
          scan_position = sentinel_end_position(scan_position)
          next
        end

        case character
        when Constants::OPEN_PARENTHESIS
          local_depth += 1
        when Constants::CLOSE_PARENTHESIS
          local_depth -= 1
          return scan_position if local_depth.zero?
        end

        scan_position += 1
      end

      nil
    end

    def detect_conjunction_at(at_position = @position)
      Constants::CONJUNCTIONS.detect do |conjunction|
        keyword_at?(conjunction, at_position)
      end
    end

    private

    def read_quoted_identifier!
      start = @position
      @position += 1

      while @position < @source.length
        if @source[@position] == Constants::DOUBLE_QUOTE
          if @position + 1 < @source.length && @source[@position + 1] == Constants::DOUBLE_QUOTE
            @position += 2
            next
          end

          @position += 1
          break
        end

        @position += 1
      end

      return nil unless @position <= @source.length && @source[@position - 1] == Constants::DOUBLE_QUOTE

      @source[start...@position]
    end

    def read_unquoted_identifier!
      start = @position
      @position += 1 while @position < @source.length && @source[@position] =~ IDENTIFIER_CHARACTER
      return nil if @position == start

      @source[start...@position]
    end
  end
end
