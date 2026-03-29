# frozen_string_literal: true

module SqlBeautifier
  class InsertQuery < Base
    include DmlRendering

    option :table_name
    option :column_list, default: -> {}
    option :values_rows, default: -> {}
    option :select_sql, default: -> {}
    option :on_conflict_clause, default: -> {}
    option :returning_clause, default: -> {}
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("insert")

      scanner.skip_past_keyword!("insert")
      return nil unless scanner.keyword_at?("into")

      scanner.skip_past_keyword!("into")

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!

      column_list = parse_column_list(normalized_sql, scanner)
      values_rows, select_sql, on_conflict_clause, returning_clause = parse_body(normalized_sql, scanner)

      return nil unless values_rows || select_sql

      new(
        table_name: table_name,
        column_list: column_list,
        values_rows: values_rows,
        select_sql: select_sql,
        on_conflict_clause: on_conflict_clause,
        returning_clause: returning_clause,
        depth: depth
      )
    end

    def render
      output = +""
      output << render_insert_into
      output << render_column_list if @column_list
      output << render_values if @values_rows
      output << render_select if @select_sql
      output << render_on_conflict if @on_conflict_clause
      output << render_returning if @returning_clause

      "#{output}\n"
    end

    def self.parse_column_list(normalized_sql, scanner)
      return nil unless scanner.position < normalized_sql.length && scanner.current_char == Constants::OPEN_PARENTHESIS

      closing = scanner.find_matching_parenthesis(scanner.position)
      return nil unless closing

      inner_text = normalized_sql[(scanner.position + 1)...closing].strip
      scanner.advance!(closing + 1 - scanner.position)
      scanner.skip_whitespace!

      return nil if inner_text.empty?

      inner_text
    end

    def self.parse_body(normalized_sql, scanner)
      remaining = normalized_sql[scanner.position..].strip
      scanner.advance!(normalized_sql.length - scanner.position)

      values_rows = nil
      select_sql = nil
      on_conflict_clause = nil
      returning_clause = nil

      remaining_scanner = Scanner.new(remaining)

      if remaining_scanner.keyword_at?("values")
        remaining_scanner.skip_past_keyword!("values")
        values_text = remaining[remaining_scanner.position..].strip
        values_rows, on_conflict_clause, returning_clause = split_values_tail(values_text)
      elsif remaining_scanner.keyword_at?("select")
        select_sql, on_conflict_clause, returning_clause = split_select_tail(remaining)
      end

      [values_rows, select_sql, on_conflict_clause, returning_clause]
    end

    def self.split_values_tail(values_text)
      rows, remaining_text = scan_value_rows(values_text)
      return [nil, nil, nil] if rows.empty?

      on_conflict_clause = nil
      returning_clause = nil

      if remaining_text.present?
        normalized_remaining = remaining_text.lstrip.downcase
        return [nil, nil, nil] unless normalized_remaining.start_with?("on conflict", "returning")

        on_conflict_clause, returning_clause = split_on_conflict_and_returning(remaining_text)
      end

      [rows, on_conflict_clause, returning_clause]
    end

    def self.scan_value_rows(values_text)
      scanner = Scanner.new(values_text)
      rows = []

      until scanner.finished?
        scanner.skip_whitespace!
        break if scanner.finished?
        break unless scanner.current_char == Constants::OPEN_PARENTHESIS

        closing = scanner.find_matching_parenthesis(scanner.position)
        break unless closing

        rows << values_text[scanner.position..(closing)]
        scanner.advance!(closing + 1 - scanner.position)
        scanner.skip_whitespace!

        break unless !scanner.finished? && scanner.current_char == Constants::COMMA

        scanner.advance!
      end

      remaining_text = values_text[scanner.position..].strip

      [rows, remaining_text]
    end

    def self.split_select_tail(remaining)
      on_conflict_position = find_top_level_keyword_position(remaining, "on conflict")
      returning_position = find_top_level_keyword_position(remaining, "returning")

      end_of_select = [on_conflict_position, returning_position].compact.min || remaining.length
      select_sql = remaining[0...end_of_select].strip

      on_conflict_clause = nil
      returning_clause = nil

      if on_conflict_position
        on_conflict_end = returning_position || remaining.length
        on_conflict_clause = remaining[on_conflict_position...on_conflict_end].strip
      end

      returning_clause = remaining[(returning_position + "returning".length)..].strip if returning_position

      [select_sql, on_conflict_clause, returning_clause]
    end

    def self.split_on_conflict_and_returning(text)
      on_conflict_position = find_top_level_keyword_position(text, "on conflict")
      returning_position = find_top_level_keyword_position(text, "returning")

      on_conflict_clause = nil
      returning_clause = nil

      if on_conflict_position
        on_conflict_end = returning_position || text.length
        on_conflict_clause = text[on_conflict_position...on_conflict_end].strip
      end

      returning_clause = text[(returning_position + "returning".length)..].strip if returning_position

      [on_conflict_clause, returning_clause]
    end

    def self.find_top_level_keyword_position(text, keyword)
      Tokenizer.find_top_level_keyword(text, keyword)
    end

    private_class_method :parse_column_list, :parse_body, :split_values_tail, :scan_value_rows, :split_select_tail, :split_on_conflict_and_returning, :find_top_level_keyword_position

    private

    def render_insert_into
      "#{Util.keyword_padding('insert into')}#{Util.format_table_name(@table_name)}"
    end

    def render_column_list
      columns = Tokenizer.split_by_top_level_commas(@column_list)
      indent = Util.whitespace(SqlBeautifier.config_for(:indent_spaces) || 4)

      formatted_columns = columns.map { |column| "#{indent}#{column.strip}" }.join(",\n")

      " (\n#{formatted_columns}\n)"
    end

    def render_values
      continuation = Util.continuation_padding

      formatted_rows = @values_rows.map.with_index do |row, index|
        if index.zero?
          "#{Util.keyword_padding('values')}#{row}"
        else
          "#{continuation}#{row}"
        end
      end

      "\n#{formatted_rows.join(",\n")}"
    end

    def render_select
      formatted_select = Formatter.new(@select_sql, depth: @depth).call
      return "" unless formatted_select

      "\n\n#{formatted_select.chomp}"
    end

    def render_on_conflict
      "\n#{@on_conflict_clause}"
    end
  end
end
