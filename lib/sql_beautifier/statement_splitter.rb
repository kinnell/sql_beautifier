# frozen_string_literal: true

module SqlBeautifier
  module StatementSplitter
    STATEMENT_KEYWORDS = %w[select with create insert update delete].freeze
    BOUNDARY_KEYWORDS = %w[from where having limit into set values].freeze
    CONTINUATION_PAIRS = { "insert" => "select" }.freeze

    module_function

    def split(sql)
      semicolon_chunks = split_on_semicolons(sql)
      statements = semicolon_chunks.flat_map { |chunk| split_concatenated_statements(chunk) }.reject(&:empty?)
      merge_trailing_sentinel_segments(statements)
    end

    def split_on_semicolons(sql)
      segments = []
      current_segment = +""
      inside_string_literal = false
      inside_quoted_identifier = false
      parenthesis_depth = 0
      position = 0

      while position < sql.length
        character = sql[position]

        if inside_string_literal
          current_segment << character

          if character == Constants::SINGLE_QUOTE && sql[position + 1] == Constants::SINGLE_QUOTE
            position += 1
            current_segment << sql[position]
          elsif character == Constants::SINGLE_QUOTE
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          current_segment << character

          if character == Constants::DOUBLE_QUOTE && sql[position + 1] == Constants::DOUBLE_QUOTE
            position += 1
            current_segment << sql[position]
          elsif character == Constants::DOUBLE_QUOTE
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        if Tokenizer.sentinel_at?(sql, position)
          end_position = Tokenizer.sentinel_end_position(sql, position)
          current_segment << sql[position...end_position]
          position = end_position
          next
        end

        case character
        when Constants::SINGLE_QUOTE
          inside_string_literal = true
          current_segment << character
        when Constants::DOUBLE_QUOTE
          inside_quoted_identifier = true
          current_segment << character
        when Constants::OPEN_PARENTHESIS
          parenthesis_depth += 1
          current_segment << character
        when Constants::CLOSE_PARENTHESIS
          parenthesis_depth = [parenthesis_depth - 1, 0].max
          current_segment << character
        when ";"
          if parenthesis_depth.zero?
            stripped = current_segment.strip
            segments << stripped unless stripped.empty?
            current_segment = +""
          else
            current_segment << character
          end
        else
          current_segment << character
        end

        position += 1
      end

      stripped = current_segment.strip
      segments << stripped unless stripped.empty?
      segments
    end

    def split_concatenated_statements(sql)
      boundaries = detect_statement_boundaries(sql)
      return [sql.strip] if boundaries.length <= 1

      statements = []

      boundaries.each_with_index do |boundary_position, index|
        end_position = begin
          if index + 1 < boundaries.length
            boundaries[index + 1]
          else
            sql.length
          end
        end

        statement = sql[boundary_position...end_position].strip
        statements << statement unless statement.empty?
      end

      statements
    end

    def detect_statement_boundaries(sql)
      boundaries = []
      clause_seen = false
      current_statement_keyword = nil
      inside_string_literal = false
      inside_quoted_identifier = false
      parenthesis_depth = 0
      position = 0

      while position < sql.length
        character = sql[position]

        if inside_string_literal
          if character == Constants::SINGLE_QUOTE && sql[position + 1] == Constants::SINGLE_QUOTE
            position += 2
          else
            inside_string_literal = false if character == Constants::SINGLE_QUOTE
            position += 1
          end
          next
        end

        if inside_quoted_identifier
          if character == Constants::DOUBLE_QUOTE && sql[position + 1] == Constants::DOUBLE_QUOTE
            position += 2
          else
            inside_quoted_identifier = false if character == Constants::DOUBLE_QUOTE
            position += 1
          end
          next
        end

        if Tokenizer.sentinel_at?(sql, position)
          position = Tokenizer.sentinel_end_position(sql, position)
          next
        end

        case character
        when Constants::SINGLE_QUOTE
          inside_string_literal = true
        when Constants::DOUBLE_QUOTE
          inside_quoted_identifier = true
        when Constants::OPEN_PARENTHESIS
          parenthesis_depth += 1
        when Constants::CLOSE_PARENTHESIS
          parenthesis_depth = [parenthesis_depth - 1, 0].max
        else
          if parenthesis_depth.zero?
            matched_statement_keyword = keyword_match_at(sql, position, STATEMENT_KEYWORDS)

            if matched_statement_keyword
              if clause_seen && !continuation_keyword?(current_statement_keyword, matched_statement_keyword)
                boundaries << position
                clause_seen = false
                current_statement_keyword = matched_statement_keyword
              elsif boundaries.empty?
                boundaries << position
                current_statement_keyword = matched_statement_keyword
              end

              position += matched_statement_keyword.length
              next
            end

            matched_boundary_keyword = keyword_match_at(sql, position, BOUNDARY_KEYWORDS)

            if matched_boundary_keyword
              clause_seen = true
              position += matched_boundary_keyword.length
              next
            end
          end
        end

        position += 1
      end

      boundaries
    end

    def merge_trailing_sentinel_segments(statements)
      return statements if statements.length <= 1

      statements.each_with_object([]) do |statement, merged|
        if sentinel_only?(statement) && merged.any?
          merged[-1] = "#{merged[-1]} #{statement}"
        else
          merged << statement
        end
      end
    end

    def sentinel_only?(segment)
      segment.gsub(CommentStripper::SENTINEL_PATTERN, "").strip.empty?
    end

    def continuation_keyword?(current_keyword, next_keyword)
      CONTINUATION_PAIRS[current_keyword] == next_keyword
    end

    def keyword_match_at(sql, position, keywords)
      keywords.detect { |keyword| Tokenizer.keyword_at?(sql, position, keyword) }
    end
  end
end
