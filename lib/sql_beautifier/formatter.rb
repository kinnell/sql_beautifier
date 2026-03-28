# frozen_string_literal: true

module SqlBeautifier
  class Formatter
    def self.call(value)
      new(value).call
    end

    def initialize(value, depth: 0)
      @value = value
      @depth = depth
    end

    def call
      return unless @value.present?

      @normalized_value = Normalizer.call(@value)
      return unless @normalized_value.present?

      @leading_sentinels = extract_leading_sentinels!
      return unless @normalized_value.present?

      cte_result = CteFormatter.format(@normalized_value, depth: @depth)
      return prepend_sentinels(cte_result) if cte_result

      create_table_as_result = CreateTableAsFormatter.format(@normalized_value, depth: @depth)
      return prepend_sentinels(create_table_as_result) if create_table_as_result

      first_clause_position = Tokenizer.first_clause_position(@normalized_value)
      return prepend_sentinels("#{@normalized_value}\n") if first_clause_position.nil? || first_clause_position.positive?

      @clauses = Tokenizer.split_into_clauses(@normalized_value)
      @table_registry = TableRegistry.new(@clauses[:from]) if @clauses[:from].present?
      @parts = []

      append_clause!(:select, Clauses::Select)
      append_from_clause!
      append_clause!(:where, Clauses::Where)
      append_clause!(:group_by, Clauses::GroupBy)
      append_clause!(:having, Clauses::Having)
      append_clause!(:order_by, Clauses::OrderBy)
      append_clause!(:limit, Clauses::Limit)

      output = @parts.join(clause_separator)
      return prepend_sentinels("#{@normalized_value}\n") if output.empty?

      output = SubqueryFormatter.format(output, @depth)
      output = @table_registry.apply_aliases(output) if @table_registry
      prepend_sentinels("#{output}\n")
    end

    private

    def extract_leading_sentinels!
      leading_sentinel_text = +""
      remaining_value = @normalized_value

      while remaining_value.match?(%r{\A#{CommentStripper::SENTINEL_PATTERN}[[:space:]]*})
        match = remaining_value.match(%r{\A(#{CommentStripper::SENTINEL_PATTERN}[[:space:]]*)})
        leading_sentinel_text << match[1]
        remaining_value = remaining_value[match[1].length..]
      end

      @normalized_value = remaining_value

      leading_sentinel_text
    end

    def prepend_sentinels(output)
      return output if @leading_sentinels.empty?

      "#{@leading_sentinels}#{output}"
    end

    def append_clause!(clause_key, formatter_class)
      value = @clauses[clause_key]
      return unless value.present?

      @parts << formatter_class.call(value)
    end

    def append_from_clause!
      value = @clauses[:from]
      return unless value.present?

      @parts << Clauses::From.call(value, table_registry: @table_registry)
    end

    def clause_separator
      return "\n\n" if SqlBeautifier.config_for(:clause_spacing_mode) == :spacious
      return "\n\n" unless compact_query?

      "\n"
    end

    def compact_query?
      compact_clause_set? && single_select_column? && single_from_table? && one_or_fewer_conditions?
    end

    def compact_clause_set?
      clause_keys = @clauses.keys
      allowed_keys = %i[select from where order_by limit]

      clause_keys.all? { |key| allowed_keys.include?(key) } && clause_keys.include?(:select) && clause_keys.include?(:from)
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
