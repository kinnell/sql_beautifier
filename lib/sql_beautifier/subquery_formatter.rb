# frozen_string_literal: true

module SqlBeautifier
  module SubqueryFormatter
    module_function

    def format(text, base_indent)
      output = +""
      position = 0

      while position < text.length
        subquery_position = find_top_level_subquery(text, position)

        unless subquery_position
          output << text[position..]
          break
        end

        output << text[position...subquery_position]

        closing_position = Tokenizer.find_matching_parenthesis(text, subquery_position)

        unless closing_position
          output << text[subquery_position..]
          break
        end

        inner_sql = text[(subquery_position + 1)...closing_position].strip
        subquery_base_indent = subquery_base_indent_for(text, subquery_position, base_indent)
        output << format_subquery(inner_sql, subquery_base_indent)
        position = closing_position + 1
      end

      output
    end

    def find_top_level_subquery(text, start_position)
      position = start_position
      in_single_quoted_string = false
      in_double_quoted_identifier = false
      while position < text.length
        character = text[position]

        if in_single_quoted_string
          if character == Constants::SINGLE_QUOTE && text[position + 1] == Constants::SINGLE_QUOTE
            position += 2
          elsif character == Constants::SINGLE_QUOTE
            in_single_quoted_string = false
            position += 1
          else
            position += 1
          end
          next
        end

        if in_double_quoted_identifier
          if character == Constants::DOUBLE_QUOTE && text[position + 1] == Constants::DOUBLE_QUOTE
            position += 2
          elsif character == Constants::DOUBLE_QUOTE
            in_double_quoted_identifier = false
            position += 1
          else
            position += 1
          end
          next
        end

        case character
        when Constants::SINGLE_QUOTE
          in_single_quoted_string = true
        when Constants::DOUBLE_QUOTE
          in_double_quoted_identifier = true
        when Constants::OPEN_PARENTHESIS
          return position if select_follows?(text, position)
        end

        position += 1
      end

      nil
    end

    def format_subquery(inner_sql, base_indent)
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      subquery_indent = base_indent + indent_spaces
      formatted = Formatter.new(inner_sql, depth: subquery_indent).call
      return "(#{inner_sql})" unless formatted

      indentation = Util.whitespace(subquery_indent)
      indented_lines = formatted.chomp.lines.map { |line| line.strip.empty? ? "\n" : "#{indentation}#{line}" }.join

      "(\n#{indented_lines}\n#{Util.whitespace(base_indent)})"
    end

    def subquery_base_indent_for(text, subquery_position, default_base_indent)
      line_start_position = text.rindex("\n", subquery_position - 1)
      line_start_position = line_start_position ? line_start_position + 1 : 0
      line_before_subquery = text[line_start_position...subquery_position]
      line_leading_spaces = line_before_subquery[%r{\A[[:space:]]*}].to_s.length

      return default_base_indent unless line_before_subquery.lstrip.match?(%r{\Awhere(?:[[:space:]]|$)}i)

      default_base_indent + line_leading_spaces + SqlBeautifier.config_for(:keyword_column_width)
    end

    def select_follows?(text, position)
      remaining_text = text[(position + 1)..]
      return false unless remaining_text

      remaining_text.match?(%r{\A[[:space:]]*select(?:[[:space:]]|\()}i)
    end
  end
end
