# frozen_string_literal: true

module SqlBeautifier
  class DeleteQuery < Base
    include DmlRendering

    option :table_name
    option :table_alias, default: -> {}
    option :using_clause, default: -> {}
    option :where_clause, default: -> {}
    option :returning_clause, default: -> {}
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("delete")

      scanner.skip_past_keyword!("delete")

      return nil unless scanner.keyword_at?("from")

      scanner.skip_past_keyword!("from")
      return nil if scanner.keyword_at?("only")

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!

      table_alias = parse_table_alias(scanner)

      remaining_text = normalized_sql[scanner.position..].strip
      clauses = split_delete_clauses(normalized_sql, scanner.position)
      return nil if remaining_text.present? && clauses.values.all?(&:nil?)

      new(
        table_name: table_name,
        table_alias: table_alias,
        using_clause: clauses[:using_clause],
        where_clause: clauses[:where_clause],
        returning_clause: clauses[:returning_clause],
        depth: depth
      )
    end

    def render
      output = +""
      output << render_delete
      output << render_from
      output << render_using if @using_clause
      output << render_where if @where_clause
      output << render_returning if @returning_clause

      "#{output}\n"
    end

    def self.parse_table_alias(scanner)
      return nil if scanner.finished?

      next_keywords = %w[using where returning]
      return nil if next_keywords.any? { |keyword| scanner.keyword_at?(keyword) }

      scanner.skip_past_keyword!("as") if scanner.keyword_at?("as")

      alias_name = scanner.read_identifier!
      scanner.skip_whitespace! if alias_name

      alias_name
    end

    def self.split_delete_clauses(normalized_sql, after_table_position)
      remaining = normalized_sql[after_table_position..]
      return {} unless remaining

      using_position = Tokenizer.find_top_level_keyword(remaining, "using")
      where_position = Tokenizer.find_top_level_keyword(remaining, "where")
      returning_position = Tokenizer.find_top_level_keyword(remaining, "returning")

      using_clause = nil
      if using_position
        using_end = [where_position, returning_position].compact.min || remaining.length
        using_clause = remaining[(using_position + "using".length)...using_end].strip
      end

      where_clause = nil
      if where_position
        where_end = returning_position || remaining.length
        where_clause = remaining[(where_position + "where".length)...where_end].strip
      end

      returning_clause = remaining[(returning_position + "returning".length)..].strip if returning_position

      {
        using_clause: using_clause.presence,
        where_clause: where_clause.presence,
        returning_clause: returning_clause.presence,
      }
    end

    private_class_method :parse_table_alias, :split_delete_clauses

    private

    def render_delete
      Util.format_keyword("delete")
    end

    def render_from
      table_reference = Util.format_table_name(@table_name)
      table_reference = "#{table_reference} #{@table_alias}" if @table_alias

      "\n#{Util.keyword_padding('from')}#{table_reference}"
    end

    def render_using
      "\n#{Util.keyword_padding('using')}#{@using_clause}"
    end
  end
end
