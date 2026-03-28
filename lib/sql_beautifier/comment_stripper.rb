# frozen_string_literal: true

module SqlBeautifier
  class CommentStripper
    SENTINEL_PREFIX = "/*__sqlb_"
    SENTINEL_SUFFIX = "__*/"
    SENTINEL_PATTERN = %r{/\*__sqlb_(\d+)__\*/}

    Result = Struct.new(:stripped_sql, :comment_map)

    def self.call(sql, removable_types)
      new(sql, removable_types).call
    end

    def initialize(sql, removable_types)
      @sql = sql
      @removal_set = resolve_removal_set(removable_types)
      @output = +""
      @comment_map = {}
      @sentinel_index = 0
      @position = 0
      @pending_separate_line_comments = []
    end

    def call
      while @position < @sql.length
        character = @sql[@position]

        if @in_single_quoted_string
          consume_single_quoted_character!(character)
        elsif @in_double_quoted_identifier
          consume_double_quoted_character!(character)
        elsif character == Constants::SINGLE_QUOTE
          flush_pending_separate_line_comments!
          @in_single_quoted_string = true
          @output << character
          @position += 1
        elsif character == Constants::DOUBLE_QUOTE
          flush_pending_separate_line_comments!
          @in_double_quoted_identifier = true
          @output << character
          @position += 1
        elsif line_comment_start?
          handle_line_comment!
        elsif block_comment_start?
          flush_pending_separate_line_comments!
          handle_block_comment!
        else
          flush_pending_separate_line_comments! unless character == "\n"
          @output << character
          @position += 1
        end
      end

      flush_pending_separate_line_comments!

      Result.new(@output, @comment_map)
    end

    private

    def resolve_removal_set(removable_types)
      case removable_types
      when :none
        []
      when :all
        Configuration::COMMENT_TYPES.dup
      when Array
        invalid_types = removable_types - Configuration::COMMENT_TYPES
        raise ArgumentError, "Unsupported removable_types entries: #{invalid_types.inspect}. Expected elements of #{Configuration::COMMENT_TYPES.inspect}" if invalid_types.any?

        removable_types
      when *Configuration::COMMENT_TYPES
        [removable_types]
      else
        raise ArgumentError, "Unsupported removable_types: #{removable_types.inspect}. Expected :none, :all, an Array, or one of #{Configuration::COMMENT_TYPES.inspect}"
      end
    end

    def consume_single_quoted_character!(character)
      @output << character

      if character == Constants::SINGLE_QUOTE && @sql[@position + 1] == Constants::SINGLE_QUOTE
        @position += 1
        @output << @sql[@position]
      elsif character == Constants::SINGLE_QUOTE
        @in_single_quoted_string = false
      end

      @position += 1
    end

    def consume_double_quoted_character!(character)
      @output << character

      if character == Constants::DOUBLE_QUOTE && @sql[@position + 1] == Constants::DOUBLE_QUOTE
        @position += 1
        @output << @sql[@position]
      elsif character == Constants::DOUBLE_QUOTE
        @in_double_quoted_identifier = false
      end

      @position += 1
    end

    def line_comment_start?
      @sql[@position] == "-" && @sql[@position + 1] == "-"
    end

    def block_comment_start?
      @sql[@position] == "/" && @sql[@position + 1] == "*"
    end

    def handle_line_comment!
      comment_type = separate_line_comment? ? :separate_line : :inline
      comment_text = extract_line_comment_text

      if removable?(comment_type)
        strip_line_comment!
      else
        preserve_line_comment!(comment_type, comment_text)
      end
    end

    def separate_line_comment?
      line_start = @output.rindex("\n")
      preceding_content = begin
        if line_start
          @output[(line_start + 1)..]
        else
          @output
        end
      end

      preceding_content.match?(%r{\A[[:space:]]*\z})
    end

    def extract_line_comment_text
      start_position = @position
      @position += 2

      @position += 1 while @position < @sql.length && @sql[@position] != "\n"

      @sql[start_position...@position]
    end

    def strip_line_comment!; end

    def preserve_line_comment!(comment_type, comment_text)
      if comment_type == :separate_line
        @pending_separate_line_comments << comment_text
        @position += 1 if @position < @sql.length && @sql[@position] == "\n"
      else
        flush_pending_separate_line_comments!
        sentinel = build_sentinel(comment_type, comment_text)
        @output << sentinel
      end
    end

    def handle_block_comment!
      comment_text = extract_block_comment_text

      if removable?(:blocks)
        strip_block_comment!
      else
        sentinel = build_sentinel(:blocks, comment_text)
        @output << " " unless @output.empty? || @output[-1] =~ Constants::WHITESPACE_CHARACTER_REGEX
        @output << sentinel

        next_character = @sql[@position]
        @output << " " if next_character && next_character !~ Constants::WHITESPACE_CHARACTER_REGEX
      end
    end

    def extract_block_comment_text
      start_position = @position
      @position += 2

      while @position < @sql.length
        if @sql[@position] == "*" && @sql[@position + 1] == "/"
          @position += 2
          break
        end

        @position += 1
      end

      @sql[start_position...@position]
    end

    def strip_block_comment!
      @output << " " unless @output.empty? || @output[-1] =~ Constants::WHITESPACE_CHARACTER_REGEX
    end

    def flush_pending_separate_line_comments!
      return if @pending_separate_line_comments.empty?

      grouped_text = @pending_separate_line_comments.join("\n")
      sentinel = build_sentinel(:separate_line, grouped_text)

      @output << sentinel
      @output << "\n"

      @pending_separate_line_comments.clear
    end

    def build_sentinel(comment_type, comment_text)
      index = @sentinel_index
      @sentinel_index += 1
      @comment_map[index] = {
        type: comment_type,
        text: comment_text,
      }

      "#{SENTINEL_PREFIX}#{index}#{SENTINEL_SUFFIX}"
    end

    def removable?(comment_type)
      @removal_set.include?(comment_type)
    end
  end
end
