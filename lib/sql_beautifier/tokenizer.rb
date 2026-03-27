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

        previous_character = match_position.zero? ? nil : sql[match_position - 1]
        next_character = match_position + keyword.length >= sql.length ? nil : sql[match_position + keyword.length]

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
        content_end = boundary_index + 1 < boundaries.length ? boundaries[boundary_index + 1][:position] : sql.length
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

          if character == "'" && text[position + 1] == "'"
            position += 1
            current_segment << text[position]
          elsif character == "'"
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          current_segment << character

          if character == '"' && text[position + 1] == '"'
            position += 1
            current_segment << text[position]
          elsif character == '"'
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        case character
        when "'"
          inside_string_literal = true
          current_segment << character

        when '"'
          inside_quoted_identifier = true
          current_segment << character

        when "("
          parenthesis_depth += 1
          current_segment << character

        when ")"
          parenthesis_depth = [parenthesis_depth - 1, 0].max
          current_segment << character

        when ","
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

    def word_boundary?(character)
      character.nil? || character !~ IDENTIFIER_CHARACTER
    end

    def top_level?(sql, target_position)
      parenthesis_depth = 0
      inside_string_literal = false
      inside_quoted_identifier = false
      position = 0

      while position < target_position
        character = sql[position]

        if inside_string_literal
          if character == "'" && sql[position + 1] == "'"
            position += 2
            next
          elsif character == "'"
            inside_string_literal = false
          end

          position += 1
          next
        end

        if inside_quoted_identifier
          if character == '"' && sql[position + 1] == '"'
            position += 2
            next
          elsif character == '"'
            inside_quoted_identifier = false
          end

          position += 1
          next
        end

        case character
        when "'"
          inside_string_literal = true
        when '"'
          inside_quoted_identifier = true
        when "("
          parenthesis_depth += 1
        when ")"
          parenthesis_depth = [parenthesis_depth - 1, 0].max
        end

        position += 1
      end

      parenthesis_depth.zero? && !inside_string_literal && !inside_quoted_identifier
    end
  end
end
