# frozen_string_literal: true

module SqlBeautifier
  class CompoundQuery < Base
    TRAILING_CLAUSE_KEYWORDS = ["order by", "limit"].freeze

    option :segments
    option :trailing_clauses, default: -> {}
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      boundaries = scan_set_operator_boundaries(normalized_sql)
      return nil if boundaries.empty?

      segments = build_segments(normalized_sql, boundaries)
      trailing_clauses = extract_trailing_clauses!(segments)

      new(segments: segments, trailing_clauses: trailing_clauses, depth: depth)
    end

    def render
      formatted_segments = []

      @segments.each_with_index do |segment, index|
        formatted_sql = Formatter.new(segment[:sql], depth: @depth).call
        return nil unless formatted_sql

        output = +""
        output << "\n#{Util.format_keyword(segment[:operator])}\n\n" if index.positive? && segment[:operator]
        output << formatted_sql.chomp
        formatted_segments << output
      end

      return nil if formatted_segments.empty?

      result = formatted_segments.join("\n")
      result << render_trailing_clauses if @trailing_clauses.present?

      "#{result}\n"
    end

    def self.scan_set_operator_boundaries(normalized_sql)
      scanner = Scanner.new(normalized_sql)
      boundaries = []

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        case scanner.current_char
        when Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
        when Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
        else
          if scanner.parenthesis_depth.zero?
            matched_operator = detect_set_operator(scanner)

            if matched_operator
              boundaries << { operator: matched_operator, position: scanner.position }
              scanner.advance!(matched_operator.length)
              next
            end
          end
        end

        scanner.advance!
      end

      boundaries
    end

    def self.detect_set_operator(scanner)
      Constants::SET_OPERATORS.detect { |operator| scanner.keyword_at?(operator) }
    end

    def self.build_segments(normalized_sql, boundaries)
      segments = []

      boundaries.each_with_index do |boundary, index|
        previous_boundary = boundaries[index - 1] unless index.zero?
        segment_start = previous_boundary ? previous_boundary[:position] + previous_boundary[:operator].length : 0
        segment_sql = normalized_sql[segment_start...boundary[:position]].strip

        segments << { operator: previous_boundary&.fetch(:operator), sql: segment_sql }
      end

      last_boundary = boundaries.last
      final_segment_start = last_boundary[:position] + last_boundary[:operator].length
      final_segment_sql = normalized_sql[final_segment_start..].strip

      segments << { operator: last_boundary[:operator], sql: final_segment_sql }

      segments
    end

    def self.extract_trailing_clauses!(segments)
      final_segment = segments.last
      return nil unless final_segment

      sql = final_segment[:sql]
      trailing_start = find_trailing_clause_start(sql)
      return nil unless trailing_start

      trailing_sql = sql[trailing_start..].strip
      final_segment[:sql] = sql[0...trailing_start].strip

      trailing_sql
    end

    def self.find_trailing_clause_start(sql)
      scanner = Scanner.new(sql)
      trailing_position = nil

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        case scanner.current_char
        when Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
        when Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
        else
          if scanner.parenthesis_depth.zero?
            matched_trailing_keyword = TRAILING_CLAUSE_KEYWORDS.detect { |keyword| scanner.keyword_at?(keyword) }
            trailing_position ||= scanner.position if matched_trailing_keyword
          end
        end

        scanner.advance!
      end

      trailing_position
    end

    private_class_method :scan_set_operator_boundaries, :detect_set_operator, :build_segments, :extract_trailing_clauses!, :find_trailing_clause_start

    private

    def render_trailing_clauses
      clauses = Tokenizer.split_into_clauses(@trailing_clauses)
      return "" if clauses.empty?

      clause_renderers = {
        order_by: Clauses::OrderBy,
        limit: Clauses::Limit,
      }

      rendered_clauses = clauses.filter_map do |clause_key, clause_value|
        renderer = clause_renderers[clause_key]
        next unless renderer

        renderer.call(clause_value)
      end

      return "" if rendered_clauses.empty?

      "\n\n#{rendered_clauses.join("\n")}"
    end
  end
end
