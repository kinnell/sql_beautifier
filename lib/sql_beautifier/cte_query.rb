# frozen_string_literal: true

module SqlBeautifier
  class CteQuery < Base
    option :recursive, type: Types::Bool
    option :definitions
    option :main_query_sql
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("with")

      scanner.skip_past_keyword!("with")

      recursive = scanner.keyword_at?("recursive")
      scanner.skip_past_keyword!("recursive") if recursive

      definitions = []

      loop do
        definition, new_position = parse_raw_definition(normalized_sql, scanner.position)
        break unless definition

        definitions << CteDefinition.new(**definition)
        scanner.advance!(new_position - scanner.position)
        scanner.skip_whitespace!

        break unless scanner.position < normalized_sql.length && scanner.current_char == Constants::COMMA

        scanner.advance!
        scanner.skip_whitespace!
      end

      main_query_sql = normalized_sql[scanner.position..].strip
      return nil unless definitions.any? && main_query_sql.present?

      new(recursive: recursive, definitions: definitions, main_query_sql: main_query_sql, depth: depth)
    end

    def self.parse_raw_definition(sql, position)
      scanner = Scanner.new(sql, position: position)

      name = scanner.read_identifier!
      return nil unless name

      scanner.skip_whitespace!

      column_list = parse_column_list(sql, scanner.position)
      scanner.advance!(column_list[:next_position] - scanner.position) if column_list

      return nil unless scanner.keyword_at?("as")

      scanner.skip_past_keyword!("as")
      materialization, materialization_end_position = parse_materialization(sql, scanner.position)
      scanner.advance!(materialization_end_position - scanner.position)

      return nil unless scanner.position < sql.length && scanner.current_char == Constants::OPEN_PARENTHESIS

      closing = scanner.find_matching_parenthesis(scanner.position)
      return nil unless closing

      body_sql = sql[(scanner.position + 1)...closing].strip
      result = { name: name, body_sql: body_sql }
      result[:column_list] = column_list[:text] if column_list
      result[:materialization] = materialization if materialization

      [result, closing + 1]
    end

    def self.parse_column_list(sql, position)
      return nil unless position < sql.length && sql[position] == Constants::OPEN_PARENTHESIS

      scanner = Scanner.new(sql)
      closing = scanner.find_matching_parenthesis(position)
      return nil unless closing

      after_paren_scanner = Scanner.new(sql, position: closing + 1)
      after_paren_scanner.skip_whitespace!
      return nil unless after_paren_scanner.keyword_at?("as")

      { text: sql[(position + 1)...closing].strip, next_position: after_paren_scanner.position }
    end

    def self.parse_materialization(sql, position)
      scanner = Scanner.new(sql, position: position)
      scanner.skip_whitespace!

      if scanner.keyword_at?("materialized")
        scanner.skip_past_keyword!("materialized")
        return ["materialized", scanner.position]
      end

      return [nil, scanner.position] unless scanner.keyword_at?("not")

      scanner.skip_past_keyword!("not")

      return [nil, position] unless scanner.keyword_at?("materialized")

      scanner.skip_past_keyword!("materialized")
      ["not materialized", scanner.position]
    end

    def render
      output = +""

      @definitions.each_with_index do |definition, index|
        if index.zero?
          output << "#{Util.format_keyword('with')} "
          output << "#{Util.format_keyword('recursive')} " if @recursive
        end

        output << definition.render_header
        output << definition.render_body(0)
        output << (index < @definitions.length - 1 ? ",\n" : "\n\n")
      end

      formatted_main = Formatter.new(@main_query_sql, depth: @depth).call
      output << formatted_main if formatted_main

      output
    end
  end
end
