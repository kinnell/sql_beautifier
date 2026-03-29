# frozen_string_literal: true

module SqlBeautifier
  module Tokenizer
    module_function

    def find_top_level_keyword(sql, keyword)
      keyword_pattern = %r{#{Regexp.escape(keyword)}}i
      search_position = 0
      scanner = Scanner.new(sql)

      while search_position < sql.length
        match = sql.match(keyword_pattern, search_position)
        return nil unless match

        match_position = match.begin(0)

        if scanner.inside_sentinel?(match_position)
          search_position = scanner.sentinel_end_position(match_position) || (match_position + 1)
          next
        end

        previous_character = scanner.character_before(match_position)
        next_character = scanner.character_after(match_position, keyword.length)

        return match_position if scanner.word_boundary?(previous_character) && scanner.word_boundary?(next_character) && top_level?(sql, match_position)

        search_position = match_position + 1
      end

      nil
    end

    def first_clause_position(sql)
      Constants::CLAUSE_KEYWORDS.filter_map { |keyword| find_top_level_keyword(sql, keyword) }.min
    end

    def split_into_clauses(sql)
      boundaries = Constants::CLAUSE_KEYWORDS.filter_map do |keyword|
        keyword_position = find_top_level_keyword(sql, keyword)
        next unless keyword_position

        {
          keyword: keyword,
          position: keyword_position,
        }
      end

      boundaries.sort_by! { |boundary| boundary[:position] }

      clauses = {}

      boundaries.each_with_index do |boundary, boundary_index|
        content_start = boundary[:position] + boundary[:keyword].length

        content_end = begin
          if boundary_index + 1 < boundaries.length
            boundaries[boundary_index + 1][:position]
          else
            sql.length
          end
        end

        clause_symbol = boundary[:keyword].tr(" ", "_").to_sym

        clauses[clause_symbol] = sql[content_start...content_end].strip
      end

      clauses
    end

    def split_by_top_level_commas(text)
      scanner = Scanner.new(text)
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

        when Constants::COMMA
          if scanner.parenthesis_depth.zero?
            segments << current_segment.strip
            current_segment = +""
          else
            current_segment << character
          end

        else
          current_segment << character
        end

        scanner.advance!
      end

      segments << current_segment.strip unless current_segment.strip.empty?
      segments
    end

    def split_top_level_conditions(text)
      conjunction_boundaries = scan_top_level_conjunctions(text)

      return [[nil, text.strip]] if conjunction_boundaries.empty?

      condition_pairs = []
      first_condition_text = text[0...conjunction_boundaries.first[:position]].strip
      condition_pairs << [nil, first_condition_text]

      conjunction_boundaries.each_with_index do |boundary, boundary_index|
        content_start = boundary[:position] + boundary[:conjunction].length

        content_end = begin
          if boundary_index + 1 < conjunction_boundaries.length
            conjunction_boundaries[boundary_index + 1][:position]
          else
            text.length
          end
        end

        condition_text = text[content_start...content_end].strip

        condition_pairs << [boundary[:conjunction], condition_text]
      end

      condition_pairs
    end

    def outer_parentheses_wrap_all?(text)
      trimmed_text = text.strip
      return false unless trimmed_text.start_with?(Constants::OPEN_PARENTHESIS)

      closing_parenthesis_position = Scanner.new(trimmed_text).find_matching_parenthesis(0)

      closing_parenthesis_position == trimmed_text.length - 1
    end

    def top_level?(sql, target_position)
      scanner = Scanner.new(sql)

      while scanner.position < target_position
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
          scanner.advance!
        end
      end

      scanner.top_level?
    end

    def scan_top_level_conjunctions(text)
      scanner = Scanner.new(text)
      conjunction_boundaries = []
      inside_between = false

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
            inside_between = true if scanner.keyword_at?(Constants::BETWEEN_KEYWORD)

            matched_conjunction = scanner.detect_conjunction_at

            if matched_conjunction
              if matched_conjunction == "and" && inside_between
                inside_between = false
              else
                conjunction_boundaries << {
                  conjunction: matched_conjunction,
                  position: scanner.position,
                }
              end

              scanner.advance!(matched_conjunction.length)
              next
            end
          end

          scanner.advance!
        end
      end

      conjunction_boundaries
    end
  end
end
