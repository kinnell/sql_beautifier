# frozen_string_literal: true

module SqlBeautifier
  module CteFormatter
    module_function

    def format(normalized_sql, depth: 0)
      return nil unless cte_query?(normalized_sql)

      recursive, definitions, main_query_sql = parse(normalized_sql)
      return nil unless definitions.any? && main_query_sql.present?

      format_cte_statement(recursive, definitions, main_query_sql, depth)
    end

    def cte_query?(sql)
      Tokenizer.keyword_at?(sql, 0, "with")
    end

    def parse(sql)
      position = skip_past_keyword(sql, 0, "with")

      recursive = Tokenizer.keyword_at?(sql, position, "recursive")
      position = skip_past_keyword(sql, position, "recursive") if recursive

      definitions = []

      loop do
        definition, new_position = parse_definition(sql, position)
        break unless definition

        definitions << definition
        position = skip_whitespace(sql, new_position)

        break unless position < sql.length && sql[position] == Constants::COMMA

        position = skip_whitespace(sql, position + 1)
      end

      main_query_sql = sql[position..].strip

      [recursive, definitions, main_query_sql]
    end

    def parse_definition(sql, position)
      name, position = read_identifier(sql, position)
      return nil unless name

      position = skip_whitespace(sql, position)

      column_list = parse_column_list(sql, position)
      position = column_list[:next_position] if column_list

      return nil unless Tokenizer.keyword_at?(sql, position, "as")

      position = skip_past_keyword(sql, position, "as")
      materialization, position = parse_materialization(sql, position)

      return nil unless position < sql.length && sql[position] == Constants::OPEN_PARENTHESIS

      closing = Tokenizer.find_matching_parenthesis(sql, position)
      return nil unless closing

      body_sql = sql[(position + 1)...closing].strip
      definition = { name: name, body: body_sql }
      definition[:column_list] = column_list[:text] if column_list
      definition[:materialization] = materialization if materialization

      [definition, closing + 1]
    end

    def parse_column_list(sql, position)
      return nil unless position < sql.length && sql[position] == Constants::OPEN_PARENTHESIS

      closing = Tokenizer.find_matching_parenthesis(sql, position)
      return nil unless closing

      after_paren = skip_whitespace(sql, closing + 1)
      return nil unless Tokenizer.keyword_at?(sql, after_paren, "as")

      { text: sql[(position + 1)...closing].strip, next_position: after_paren }
    end

    def format_cte_statement(recursive, definitions, main_query_sql, depth)
      keyword_width = SqlBeautifier.config_for(:keyword_column_width)
      cte_name_column = keyword_width
      continuation_indent = Util.continuation_padding

      output = +""

      definitions.each_with_index do |definition, index|
        if index.zero?
          output << Util.keyword_padding("with")
          output << "#{Util.format_keyword('recursive')} " if recursive
        else
          output << continuation_indent
        end

        output << definition_header(definition)
        output << format_body(definition[:body], cte_name_column)
        output << (index < definitions.length - 1 ? ",\n" : "\n\n")
      end

      formatted_main = Formatter.new(main_query_sql, depth: depth).call
      output << formatted_main if formatted_main

      output
    end

    def definition_header(definition)
      header = +definition[:name].to_s
      header << " (#{definition[:column_list]})" if definition[:column_list]
      header << " #{Util.format_keyword('as')}"
      header << " #{format_materialization(definition[:materialization])}" if definition[:materialization]
      header << " "
      header
    end

    def parse_materialization(sql, position)
      position = skip_whitespace(sql, position)
      return ["materialized", skip_past_keyword(sql, position, "materialized")] if Tokenizer.keyword_at?(sql, position, "materialized")
      return [nil, position] unless Tokenizer.keyword_at?(sql, position, "not")

      materialized_position = skip_past_keyword(sql, position, "not")
      return [nil, position] unless Tokenizer.keyword_at?(sql, materialized_position, "materialized")

      ["not materialized", skip_past_keyword(sql, materialized_position, "materialized")]
    end

    def format_materialization(materialization)
      return Util.format_keyword("materialized") if materialization == "materialized"

      [Util.format_keyword("not"), Util.format_keyword("materialized")].join(" ")
    end

    def format_body(body_sql, base_indent)
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      body_indent = base_indent + indent_spaces
      formatted = Formatter.new(body_sql, depth: 0).call
      return "(#{body_sql})" unless formatted

      indentation = Util.whitespace(body_indent)
      indented_lines = formatted.chomp.lines.map { |line| line.strip.empty? ? "\n" : "#{indentation}#{line}" }.join

      "(\n#{indented_lines}\n#{Util.whitespace(base_indent)})"
    end

    def read_identifier(sql, position)
      position = skip_whitespace(sql, position)
      return nil if position >= sql.length

      if sql[position] == Constants::DOUBLE_QUOTE
        start = position
        position += 1

        while position < sql.length
          if sql[position] == Constants::DOUBLE_QUOTE
            if position + 1 < sql.length && sql[position + 1] == Constants::DOUBLE_QUOTE
              position += 2
              next
            end

            position += 1
            break
          end

          position += 1
        end

        return nil unless position <= sql.length && sql[position - 1] == Constants::DOUBLE_QUOTE

        return [sql[start...position], position]
      end

      start = position
      position += 1 while position < sql.length && sql[position] =~ Tokenizer::IDENTIFIER_CHARACTER
      return nil if position == start

      [sql[start...position], position]
    end

    def skip_whitespace(sql, position)
      position += 1 while position < sql.length && sql[position] =~ Constants::WHITESPACE_CHARACTER_REGEX
      position
    end

    def skip_past_keyword(sql, position, keyword)
      skip_whitespace(sql, position + keyword.length)
    end
  end
end
