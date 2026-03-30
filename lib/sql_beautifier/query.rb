# frozen_string_literal: true

module SqlBeautifier
  class Query
    COMPACT_CLAUSE_KEYS = %i[
      select
      from
      where
      order_by
      limit
    ].freeze

    LEADING_WHITESPACE_PATTERN = %r{\A[[:space:]]*}
    CLAUSE_KEYWORD_PREFIX_PATTERN = %r{\A(?:where|from)(?:[[:space:]]|$)}i

    attr_reader :clauses
    attr_reader :depth
    attr_reader :table_registry

    def self.parse(normalized_sql, depth: 0)
      clauses = Tokenizer.split_into_clauses(normalized_sql)

      new(clauses: clauses, depth: depth)
    end

    def self.format_as_subquery(inner_sql, base_indent:)
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      subquery_indent = base_indent + indent_spaces
      formatted = Formatter.new(inner_sql, depth: subquery_indent).call
      return "(#{inner_sql})" unless formatted

      indentation = Util.whitespace(subquery_indent)
      indented_lines = formatted.chomp.lines.map do |line|
        line.strip.empty? ? "\n" : "#{indentation}#{line}"
      end.join

      "(\n#{indented_lines}\n#{Util.whitespace(base_indent)})"
    end

    def self.format_subqueries_in_text(text, depth:)
      output = +""
      position = 0

      while position < text.length
        subquery_position = find_top_level_subquery(text, position)

        unless subquery_position
          output << text[position..]
          break
        end

        output << text[position...subquery_position]

        closing_position = Scanner.new(text).find_matching_parenthesis(subquery_position)

        unless closing_position
          output << text[subquery_position..]
          break
        end

        inner_sql = text[(subquery_position + 1)...closing_position].strip
        base_indent = subquery_base_indent_for(text, subquery_position, depth)
        output << format_as_subquery(inner_sql, base_indent: base_indent)
        position = closing_position + 1
      end

      output
    end

    def self.find_top_level_subquery(text, start_position)
      scanner = Scanner.new(text, position: start_position)

      until scanner.finished?
        consumed = scanner.scan_quoted_or_sentinel!
        next if consumed

        return scanner.position if scanner.current_char == Constants::OPEN_PARENTHESIS && select_follows?(text, scanner.position)

        scanner.advance!
      end

      nil
    end

    def self.subquery_base_indent_for(text, subquery_position, default_base_indent)
      line_start_position = text.rindex("\n", subquery_position - 1)
      line_start_position = line_start_position ? line_start_position + 1 : 0
      line_before_subquery = text[line_start_position...subquery_position]
      line_leading_spaces = line_before_subquery[LEADING_WHITESPACE_PATTERN].to_s.length

      return default_base_indent unless line_before_subquery.lstrip.match?(CLAUSE_KEYWORD_PREFIX_PATTERN)

      default_base_indent + line_leading_spaces + SqlBeautifier.config_for(:keyword_column_width)
    end

    def self.select_follows?(text, position)
      remaining_text = text[(position + 1)..]
      return false unless remaining_text

      remaining_text.match?(%r{\A[[:space:]]*select(?:[[:space:]]|\()}i)
    end

    def initialize(clauses:, depth: 0)
      @clauses = clauses
      @depth = depth
      @table_registry = TableRegistry.new(@clauses[:from]) if @clauses[:from].present?
    end

    def render
      parts = []

      append_clause!(parts, :select, Clauses::Select)
      append_from_clause!(parts)
      append_clause!(parts, :where, Clauses::Where)
      append_clause!(parts, :group_by, Clauses::GroupBy)
      append_clause!(parts, :having, Clauses::Having)
      append_clause!(parts, :order_by, Clauses::OrderBy)
      append_clause!(parts, :limit, Clauses::Limit)

      output = parts.join(clause_separator)
      return nil if output.empty?

      output = self.class.format_subqueries_in_text(output, depth: @depth)
      output = @table_registry.apply_aliases(output) if @table_registry
      "#{output}\n"
    end

    def compact?
      compact_clause_set? && single_select_column? && single_from_table? && one_or_fewer_conditions?
    end

    private

    def append_clause!(parts, clause_key, formatter_class)
      value = @clauses[clause_key]
      return unless value.present?

      parts << formatter_class.call(value)
    end

    def append_from_clause!(parts)
      value = @clauses[:from]
      return unless value.present?

      parts << Clauses::From.call(value, table_registry: @table_registry)
    end

    def clause_separator
      return "\n\n" if SqlBeautifier.config_for(:clause_spacing_mode) == :spacious
      return "\n\n" unless compact?

      "\n"
    end

    def compact_clause_set?
      clause_keys = @clauses.keys
      clause_keys.all? { |key| COMPACT_CLAUSE_KEYS.include?(key) } && clause_keys.include?(:select) && clause_keys.include?(:from)
    end

    def single_select_column?
      select_value = @clauses[:select]
      return false unless select_value.present?

      formatted_select = Clauses::Select.call(select_value)
      formatted_select.lines.length == 1
    end

    def single_from_table?
      from_value = @clauses[:from]
      return false unless from_value.present?

      join_keywords = Constants::JOIN_KEYWORDS_BY_LENGTH.any? { |keyword| Tokenizer.find_top_level_keyword(from_value, keyword) }
      return false if join_keywords

      !from_value.match?(%r{,})
    end

    def one_or_fewer_conditions?
      where_value = @clauses[:where]
      return true unless where_value.present?

      Tokenizer.split_top_level_conditions(where_value).length <= 1
    end
  end
end
