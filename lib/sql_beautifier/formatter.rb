# frozen_string_literal: true

module SqlBeautifier
  class Formatter
    LEADING_SENTINEL_PATTERN = %r{\A#{CommentParser::SENTINEL_PATTERN}[[:space:]]*}
    LEADING_SENTINEL_CAPTURE = %r{\A(#{CommentParser::SENTINEL_PATTERN}[[:space:]]*)}

    def self.call(...)
      new(...).call
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

      cte_result = CteQuery.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(cte_result) if cte_result

      create_table_as_result = CreateTableAs.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(create_table_as_result) if create_table_as_result

      compound_result = CompoundQuery.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(compound_result) if compound_result

      insert_result = InsertQuery.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(insert_result) if insert_result

      update_result = UpdateQuery.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(update_result) if update_result

      delete_result = DeleteQuery.parse(@normalized_value, depth: @depth)&.render
      return prepend_sentinels(delete_result) if delete_result

      first_clause_position = Tokenizer.first_clause_position(@normalized_value)
      return prepend_sentinels("#{@normalized_value}\n") if first_clause_position.nil? || first_clause_position.positive?

      query = Query.parse(@normalized_value, depth: @depth)
      result = query.render
      return prepend_sentinels("#{@normalized_value}\n") unless result

      prepend_sentinels(result)
    end

    private

    def extract_leading_sentinels!
      leading_sentinel_text = +""
      remaining_value = @normalized_value

      while remaining_value.match?(LEADING_SENTINEL_PATTERN)
        match = remaining_value.match(LEADING_SENTINEL_CAPTURE)
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
  end
end
