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
      scanner = Scanner.new(sql)
      segments = []
      current_segment = +""

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        if consumed
          current_segment << consumed
          next
        end

        character = scanner.current_char

        case character
        when Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          current_segment << character

        when Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          current_segment << character

        when ";"
          if scanner.parenthesis_depth.zero?
            stripped_segment = current_segment.strip
            segments << stripped_segment unless stripped_segment.empty?
            current_segment = +""
          else
            current_segment << character
          end

        else
          current_segment << character
        end

        scanner.advance!
      end

      stripped_segment = current_segment.strip
      segments << stripped_segment unless stripped_segment.empty?
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
      scanner = Scanner.new(sql)
      boundaries = []
      clause_seen = false
      current_statement_keyword = nil

      until scanner.finished?
        next if scanner.skip_quoted_or_sentinel!

        case scanner.current_char
        when Constants::SINGLE_QUOTE
          scanner.enter_single_quote!
        when Constants::DOUBLE_QUOTE
          scanner.enter_double_quote!
        when Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
        when Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
        else
          if scanner.parenthesis_depth.zero?
            matched_statement_keyword = keyword_match_at(scanner, STATEMENT_KEYWORDS)

            if matched_statement_keyword
              if clause_seen && !continuation_keyword?(current_statement_keyword, matched_statement_keyword)
                boundaries << scanner.position
                clause_seen = false
                current_statement_keyword = matched_statement_keyword
              elsif boundaries.empty?
                boundaries << scanner.position
                current_statement_keyword = matched_statement_keyword
              end

              scanner.advance!(matched_statement_keyword.length)
              next
            end

            matched_boundary_keyword = keyword_match_at(scanner, BOUNDARY_KEYWORDS)

            if matched_boundary_keyword
              clause_seen = true
              scanner.advance!(matched_boundary_keyword.length)
              next
            end
          end

          scanner.advance!
        end
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
      segment.gsub(CommentParser::SENTINEL_PATTERN, "").strip.empty?
    end

    def continuation_keyword?(current_keyword, next_keyword)
      CONTINUATION_PAIRS[current_keyword] == next_keyword
    end

    def keyword_match_at(scanner, keywords)
      keywords.detect { |keyword| scanner.keyword_at?(keyword) }
    end
  end
end
