# frozen_string_literal: true

module SqlBeautifier
  class CreateTable < Base
    extend CreateTableParsing

    option :modifier, default: -> {}
    option :if_not_exists, type: Types::Bool
    option :table_name
    option :column_definitions

    def self.parse(normalized_sql, **)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("create")

      scanner.skip_past_keyword!("create")
      modifier = detect_modifier(scanner)
      scanner.skip_past_keyword!(modifier) if modifier

      return nil unless scanner.keyword_at?("table")

      scanner.skip_past_keyword!("table")

      if_not_exists = detect_if_not_exists?(scanner)
      skip_past_if_not_exists!(scanner) if if_not_exists

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!
      return nil if scanner.finished?
      return nil unless scanner.current_char == Constants::OPEN_PARENTHESIS

      column_definitions = extract_column_definitions(normalized_sql, scanner)
      return nil unless column_definitions

      new(modifier: modifier, if_not_exists: if_not_exists, table_name: table_name, column_definitions: column_definitions)
    end

    def self.extract_column_definitions(normalized_sql, scanner)
      closing = scanner.find_matching_parenthesis(scanner.position)
      return nil unless closing

      inner_text = normalized_sql[(scanner.position + 1)...closing].strip
      return nil if inner_text.empty?

      trailing_text = normalized_sql[(closing + 1)..].strip
      return nil unless trailing_text.empty?

      inner_text
    end

    private_class_method :extract_column_definitions

    def render
      parts = [Util.format_keyword("create")]
      parts << Util.format_keyword(@modifier) if @modifier
      parts << Util.format_keyword("table")
      parts << "#{Util.format_keyword('if')} #{Util.format_keyword('not')} #{Util.format_keyword('exists')}" if @if_not_exists
      parts << Util.format_table_name(@table_name)

      "#{parts.join(' ')} (#{@column_definitions})\n"
    end
  end
end
