# frozen_string_literal: true

module SqlBeautifier
  class CaseExpression < Base
    CASE_KEYWORD = "case"
    WHEN_KEYWORD = "when"
    THEN_KEYWORD = "then"
    ELSE_KEYWORD = "else"
    END_KEYWORD = "end"

    option :operand, default: -> {}
    option :when_clauses
    option :else_value, default: -> {}
    option :base_indent, default: -> { 0 }

    def self.format_in_text(text, base_indent: 0)
      output = +""
      scanner = Scanner.new(text)

      while scanner.position < text.length
        consumed = scanner.scan_quoted_or_sentinel!
        if consumed
          output << consumed
          next
        end

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          output << scanner.current_char
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          output << scanner.current_char
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero? && scanner.keyword_at?(CASE_KEYWORD)
          case_start = scanner.position
          end_position = find_matching_end(text, case_start)

          unless end_position
            output << scanner.current_char
            scanner.advance!
            next
          end

          case_text = text[case_start...(end_position + END_KEYWORD.length)]
          parsed = parse(case_text, base_indent: base_indent)
          output << (parsed ? parsed.render : case_text)

          scanner.advance!(end_position + END_KEYWORD.length - scanner.position)
          next
        end

        output << scanner.current_char
        scanner.advance!
      end

      output
    end

    def self.parse(text, base_indent: 0)
      stripped = text.strip
      scanner = Scanner.new(stripped)
      return nil unless scanner.keyword_at?(CASE_KEYWORD)

      scanner.skip_past_keyword!(CASE_KEYWORD)

      operand = extract_operand(stripped, scanner)
      when_clauses = []
      else_value = nil
      case_depth = 1

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero?
          if scanner.keyword_at?(CASE_KEYWORD)
            case_depth += 1
            scanner.advance!(CASE_KEYWORD.length)
            next
          end

          if scanner.keyword_at?(END_KEYWORD)
            case_depth -= 1

            if case_depth.zero?
              return new(
                operand: operand,
                when_clauses: when_clauses,
                else_value: else_value,
                base_indent: base_indent
              )
            end

            scanner.advance!(END_KEYWORD.length)
            next
          end

          if case_depth == 1
            if scanner.keyword_at?(WHEN_KEYWORD)
              parsed_clause = parse_when_clause(stripped, scanner)
              return nil unless parsed_clause

              when_clauses << parsed_clause
              next
            end

            if scanner.keyword_at?(ELSE_KEYWORD)
              else_value = parse_else_value(stripped, scanner)
              next
            end
          end
        end

        scanner.advance!
      end

      nil
    end

    def render
      inline_version = render_inline
      threshold = SqlBeautifier.config_for(:inline_group_threshold)

      return inline_version if inline_version.length <= threshold

      render_expanded
    end

    private

    def render_inline
      parts = +"case"
      parts << " #{@operand}" if @operand

      @when_clauses.each do |clause|
        parts << " when #{clause[:condition]} then #{clause[:result]}"
      end

      parts << " else #{@else_value}" if @else_value
      parts << " end"

      parts
    end

    def render_expanded
      indent_spaces = SqlBeautifier.config_for(:indent_spaces)
      body_indent = Util.whitespace(@base_indent + indent_spaces)
      closing_indent = Util.whitespace(@base_indent)
      nested_base_indent = @base_indent + indent_spaces

      lines = []

      case_line = +"case"
      case_line << " #{@operand}" if @operand
      lines << case_line

      @when_clauses.each do |clause|
        formatted_condition = CaseExpression.format_in_text(clause[:condition], base_indent: nested_base_indent)
        formatted_result = CaseExpression.format_in_text(clause[:result], base_indent: nested_base_indent)
        lines << "#{body_indent}when #{formatted_condition} then #{formatted_result}"
      end

      if @else_value
        formatted_else = CaseExpression.format_in_text(@else_value, base_indent: nested_base_indent)
        lines << "#{body_indent}else #{formatted_else}"
      end

      lines << "#{closing_indent}end"

      lines.join("\n")
    end

    def self.extract_operand(text, scanner)
      start_position = scanner.position
      operand_scanner = Scanner.new(text, position: start_position)

      until operand_scanner.finished?
        consumed = operand_scanner.scan_quoted_or_sentinel!
        next if consumed

        if operand_scanner.current_char == Constants::OPEN_PARENTHESIS
          operand_scanner.increment_depth!
          operand_scanner.advance!
          next
        end

        if operand_scanner.current_char == Constants::CLOSE_PARENTHESIS
          operand_scanner.decrement_depth!
          operand_scanner.advance!
          next
        end

        if operand_scanner.parenthesis_depth.zero? && operand_scanner.keyword_at?(WHEN_KEYWORD)
          operand_text = text[start_position...operand_scanner.position].strip
          scanner.advance!(operand_scanner.position - scanner.position)

          return operand_text.empty? ? nil : operand_text
        end

        operand_scanner.advance!
      end

      scanner.advance!(operand_scanner.position - scanner.position)
      nil
    end

    def self.parse_when_clause(text, scanner)
      scanner.skip_past_keyword!(WHEN_KEYWORD)
      condition_start = scanner.position
      case_depth = 0

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero?
          if scanner.keyword_at?(CASE_KEYWORD)
            case_depth += 1
            scanner.advance!(CASE_KEYWORD.length)
            next
          end

          if scanner.keyword_at?(END_KEYWORD) && case_depth.positive?
            case_depth -= 1
            scanner.advance!(END_KEYWORD.length)
            next
          end

          if case_depth.zero? && scanner.keyword_at?(THEN_KEYWORD)
            condition = text[condition_start...scanner.position].strip
            scanner.skip_past_keyword!(THEN_KEYWORD)
            then_result = parse_then_result(text, scanner)

            return { condition: condition, result: then_result }
          end
        end

        scanner.advance!
      end

      nil
    end

    def self.parse_then_result(text, scanner)
      result_start = scanner.position
      case_depth = 0

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero?
          if scanner.keyword_at?(CASE_KEYWORD)
            case_depth += 1
            scanner.advance!(CASE_KEYWORD.length)
            next
          end

          if scanner.keyword_at?(END_KEYWORD) && case_depth.positive?
            case_depth -= 1
            scanner.advance!(END_KEYWORD.length)
            next
          end

          return text[result_start...scanner.position].strip if case_depth.zero? && (scanner.keyword_at?(WHEN_KEYWORD) || scanner.keyword_at?(ELSE_KEYWORD) || scanner.keyword_at?(END_KEYWORD))
        end

        scanner.advance!
      end

      text[result_start...scanner.position].strip
    end

    def self.parse_else_value(text, scanner)
      scanner.skip_past_keyword!(ELSE_KEYWORD)
      else_start = scanner.position
      case_depth = 0

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero?
          if scanner.keyword_at?(CASE_KEYWORD)
            case_depth += 1
            scanner.advance!(CASE_KEYWORD.length)
            next
          end

          if scanner.keyword_at?(END_KEYWORD) && case_depth.positive?
            case_depth -= 1
            scanner.advance!(END_KEYWORD.length)
            next
          end

          return text[else_start...scanner.position].strip if case_depth.zero? && scanner.keyword_at?(END_KEYWORD)
        end

        scanner.advance!
      end

      text[else_start...scanner.position].strip
    end

    def self.find_matching_end(text, case_start)
      scanner = Scanner.new(text, position: case_start)
      scanner.advance!(CASE_KEYWORD.length)
      case_depth = 1

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        if scanner.current_char == Constants::OPEN_PARENTHESIS
          scanner.increment_depth!
          scanner.advance!
          next
        end

        if scanner.current_char == Constants::CLOSE_PARENTHESIS
          scanner.decrement_depth!
          scanner.advance!
          next
        end

        if scanner.parenthesis_depth.zero?
          if scanner.keyword_at?(CASE_KEYWORD)
            case_depth += 1
            scanner.advance!(CASE_KEYWORD.length)
            next
          end

          if scanner.keyword_at?(END_KEYWORD)
            case_depth -= 1
            return scanner.position if case_depth.zero?

            scanner.advance!(END_KEYWORD.length)
            next
          end
        end

        scanner.advance!
      end

      nil
    end

    private_class_method :extract_operand, :parse_when_clause, :parse_then_result, :parse_else_value, :find_matching_end
  end
end
