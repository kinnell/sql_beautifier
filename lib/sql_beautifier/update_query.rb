# frozen_string_literal: true

module SqlBeautifier
  class UpdateQuery < Base
    include DmlRendering

    option :table_name
    option :assignments
    option :from_clause, default: -> {}
    option :where_clause, default: -> {}
    option :returning_clause, default: -> {}
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("update")

      scanner.skip_past_keyword!("update")

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!
      return nil unless scanner.keyword_at?("set")

      scanner.skip_past_keyword!("set")

      clauses = split_update_clauses(normalized_sql, scanner.position)
      return nil unless clauses[:assignments]

      new(
        table_name: table_name,
        assignments: clauses[:assignments],
        from_clause: clauses[:from_clause],
        where_clause: clauses[:where_clause],
        returning_clause: clauses[:returning_clause],
        depth: depth
      )
    end

    def render
      output = +""
      output << render_update
      output << render_assignments
      output << render_from if @from_clause
      output << render_where if @where_clause
      output << render_returning if @returning_clause

      "#{output}\n"
    end

    def self.split_update_clauses(normalized_sql, set_content_start)
      remaining = normalized_sql[set_content_start..]

      from_position = Tokenizer.find_top_level_keyword(remaining, "from")
      where_position = Tokenizer.find_top_level_keyword(remaining, "where")
      returning_position = Tokenizer.find_top_level_keyword(remaining, "returning")

      assignments_end = [from_position, where_position, returning_position].compact.min || remaining.length
      assignments_text = remaining[0...assignments_end].strip

      from_clause = nil
      if from_position
        from_end = [where_position, returning_position].compact.min || remaining.length
        from_clause = remaining[(from_position + "from".length)...from_end].strip
      end

      where_clause = nil
      if where_position
        where_end = returning_position || remaining.length
        where_clause = remaining[(where_position + "where".length)...where_end].strip
      end

      returning_clause = remaining[(returning_position + "returning".length)..].strip if returning_position

      {
        assignments: assignments_text.presence,
        from_clause: from_clause.presence,
        where_clause: where_clause.presence,
        returning_clause: returning_clause.presence,
      }
    end

    private_class_method :split_update_clauses

    private

    def render_update
      "#{Util.keyword_padding('update')}#{Util.format_table_name(@table_name)}"
    end

    def render_assignments
      items = Tokenizer.split_by_top_level_commas(@assignments)
      continuation = Util.continuation_padding
      keyword_width = SqlBeautifier.config_for(:keyword_column_width)

      formatted_items = items.map.with_index do |item, index|
        formatted_item = CaseExpression.format_in_text(item.strip, base_indent: keyword_width)

        if index.zero?
          "\n#{Util.keyword_padding('set')}#{formatted_item}"
        else
          "\n#{continuation}#{formatted_item}"
        end
      end

      formatted_items.join(",")
    end

    def render_from
      "\n#{Util.keyword_padding('from')}#{@from_clause}"
    end
  end
end
