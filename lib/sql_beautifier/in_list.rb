# frozen_string_literal: true

module SqlBeautifier
  module InList
    IN_KEYWORD = "in"
    NOT_IN_KEYWORD = "not in"
    SUBQUERY_PATTERN = %r{\A[[:space:]]*select(?:[[:space:]]|\()}i

    module_function

    def format_in_text(text, base_indent: 0)
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

        if scanner.parenthesis_depth.zero? && in_keyword_at?(scanner)
          keyword_length = in_keyword_length_at(scanner)
          parenthesis_position = find_opening_parenthesis(text, scanner.position + keyword_length)

          if parenthesis_position
            expansion = format_in_list(text, keyword_position: scanner.position, parenthesis_position: parenthesis_position, base_indent: base_indent)

            if expansion
              output << expansion[:text]
              scanner.advance!(expansion[:consumed] - scanner.position)
              next
            end
          end
        end

        output << scanner.current_char
        scanner.advance!
      end

      output
    end

    def in_keyword_at?(scanner)
      scanner.keyword_at?(NOT_IN_KEYWORD) || scanner.keyword_at?(IN_KEYWORD)
    end

    def in_keyword_length_at(scanner)
      scanner.keyword_at?(NOT_IN_KEYWORD) ? NOT_IN_KEYWORD.length : IN_KEYWORD.length
    end

    def find_opening_parenthesis(text, from_position)
      position = from_position

      while position < text.length
        return position if text[position] == Constants::OPEN_PARENTHESIS
        return nil unless text[position] =~ Constants::WHITESPACE_CHARACTER_REGEX

        position += 1
      end

      nil
    end

    def format_in_list(text, keyword_position:, parenthesis_position:, base_indent:)
      closing_position = Scanner.new(text).find_matching_parenthesis(parenthesis_position)
      return nil unless closing_position

      inner_text = text[(parenthesis_position + 1)...closing_position]
      return nil if inner_text.match?(SUBQUERY_PATTERN)

      items = Tokenizer.split_by_top_level_commas(inner_text)
      return nil if items.length <= 1

      keyword_text = text[keyword_position...(parenthesis_position + 1)]
      indent_spaces = SqlBeautifier.config_for(:indent_spaces)
      item_indent = Util.whitespace(base_indent + indent_spaces)
      closing_indent = Util.whitespace(base_indent)

      formatted_items = items.map.with_index do |item, index|
        trailing_comma = index < items.length - 1 ? "," : ""
        "#{item_indent}#{item}#{trailing_comma}"
      end

      {
        text: "#{keyword_text}\n#{formatted_items.join("\n")}\n#{closing_indent})",
        consumed: closing_position + 1,
      }
    end

    private_class_method :in_keyword_at?, :in_keyword_length_at, :find_opening_parenthesis, :format_in_list
  end
end
