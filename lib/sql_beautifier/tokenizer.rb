# frozen_string_literal: true

module SqlBeautifier
  module Tokenizer
    IDENTIFIER_CHARACTER = %r{[[:alnum:]_$]}

    module_function

    def find_top_level_keyword(sql, keyword)
      keyword_pattern = %r{#{Regexp.escape(keyword)}}i
      search_position = 0

      while search_position < sql.length
        match = sql.match(keyword_pattern, search_position)
        return nil unless match

        match_position = match.begin(0)

        if inside_sentinel?(sql, match_position)
          search_position = sentinel_end_position(sql, match_position) || (match_position + 1)
          next
        end

        previous_character = character_before(sql, match_position)
        next_character = character_after(sql, match_position, keyword.length)

        return match_position if word_boundary?(previous_character) && word_boundary?(next_character) && top_level?(sql, match_position)

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
      segments = []
      current_segment = +""
      parenthesis_depth = 0
      inside_string_literal = false
      inside_quoted_identifier = false
      position = 0

      while position < text.length
        character = text[position]

        if inside_string_literal
          current_segment << character

          if escaped_single_quote?(text, position)
            position += 1
            current_segment << text[position]
          elsif character == Constants::SINGLE_QUOTE
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          current_segment << character

          if escaped_double_quote?(text, position)
            position += 1
            current_segment << text[position]
          elsif character == Constants::DOUBLE_QUOTE
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        if sentinel_at?(text, position)
          end_position = sentinel_end_position(text, position)
          current_segment << text[position...end_position]
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

        when Constants::COMMA
          if parenthesis_depth.zero?
            segments << current_segment.strip
            current_segment = +""
          else
            current_segment << character
          end

        else
          current_segment << character
        end

        position += 1
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

    def find_matching_parenthesis(text, opening_position)
      parenthesis_depth = 0
      inside_string_literal = false
      inside_quoted_identifier = false
      position = opening_position

      while position < text.length
        character = text[position]

        if inside_string_literal
          if escaped_single_quote?(text, position)
            position += 2
            next
          elsif character == Constants::SINGLE_QUOTE
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          if escaped_double_quote?(text, position)
            position += 2
            next
          elsif character == Constants::DOUBLE_QUOTE
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        if sentinel_at?(text, position)
          position = sentinel_end_position(text, position)
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
          parenthesis_depth -= 1
          return position if parenthesis_depth.zero?
        end

        position += 1
      end

      nil
    end

    def outer_parentheses_wrap_all?(text)
      trimmed_text = text.strip
      return false unless trimmed_text.start_with?(Constants::OPEN_PARENTHESIS)

      closing_parenthesis_position = find_matching_parenthesis(trimmed_text, 0)

      closing_parenthesis_position == trimmed_text.length - 1
    end

    def word_boundary?(character)
      character.nil? || character !~ IDENTIFIER_CHARACTER
    end

    def character_before(text, position)
      return nil if position.zero?

      text[position - 1]
    end

    def character_after(text, position, offset)
      return nil if position + offset >= text.length

      text[position + offset]
    end

    def escaped_single_quote?(text, position)
      text[position] == Constants::SINGLE_QUOTE && text[position + 1] == Constants::SINGLE_QUOTE
    end

    def escaped_double_quote?(text, position)
      text[position] == Constants::DOUBLE_QUOTE && text[position + 1] == Constants::DOUBLE_QUOTE
    end

    def sentinel_at?(text, position)
      text[position, CommentStripper::SENTINEL_PREFIX.length] == CommentStripper::SENTINEL_PREFIX
    end

    def sentinel_end_position(text, position)
      closing = text.index(CommentStripper::SENTINEL_SUFFIX, position + CommentStripper::SENTINEL_PREFIX.length)
      return position + 1 unless closing

      closing + CommentStripper::SENTINEL_SUFFIX.length
    end

    def inside_sentinel?(text, position)
      search_start = [position - 20, 0].max
      prefix_position = text.rindex(CommentStripper::SENTINEL_PREFIX, position)
      return false unless prefix_position && prefix_position >= search_start

      end_position = sentinel_end_position(text, prefix_position)
      position < end_position
    end

    def top_level?(sql, target_position)
      parenthesis_depth = 0
      inside_string_literal = false
      inside_quoted_identifier = false
      position = 0

      while position < target_position
        character = sql[position]

        if inside_string_literal
          if escaped_single_quote?(sql, position)
            position += 2
            next
          elsif character == Constants::SINGLE_QUOTE
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          if escaped_double_quote?(sql, position)
            position += 2
            next
          elsif character == Constants::DOUBLE_QUOTE
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        if sentinel_at?(sql, position)
          position = sentinel_end_position(sql, position)
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
        end

        position += 1
      end

      parenthesis_depth.zero? && !inside_string_literal && !inside_quoted_identifier
    end

    def scan_top_level_conjunctions(text)
      conjunction_boundaries = []
      parenthesis_depth = 0
      inside_string_literal = false
      inside_quoted_identifier = false
      inside_between = false
      position = 0

      while position < text.length
        character = text[position]

        if inside_string_literal
          if escaped_single_quote?(text, position)
            position += 2
          elsif character == Constants::SINGLE_QUOTE
            inside_string_literal = false
            position += 1
          else
            position += 1
          end
          next
        end

        if inside_quoted_identifier
          if escaped_double_quote?(text, position)
            position += 2
          elsif character == Constants::DOUBLE_QUOTE
            inside_quoted_identifier = false
            position += 1
          else
            position += 1
          end
          next
        end

        if sentinel_at?(text, position)
          position = sentinel_end_position(text, position)
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
            inside_between = true if keyword_at?(text, position, Constants::BETWEEN_KEYWORD)

            matched_conjunction = detect_conjunction_at(text, position)

            if matched_conjunction
              if matched_conjunction == "and" && inside_between
                inside_between = false
              else
                conjunction_boundaries << {
                  conjunction: matched_conjunction,
                  position: position,
                }
              end

              position += matched_conjunction.length
              next
            end
          end
        end

        position += 1
      end

      conjunction_boundaries
    end

    def keyword_at?(text, position, keyword)
      return false unless text[position, keyword.length]&.downcase == keyword

      previous_character = character_before(text, position)
      next_character = character_after(text, position, keyword.length)

      word_boundary?(previous_character) && word_boundary?(next_character)
    end

    def detect_conjunction_at(text, position)
      Constants::CONJUNCTIONS.detect do |conjunction|
        keyword_at?(text, position, conjunction)
      end
    end
  end
end
