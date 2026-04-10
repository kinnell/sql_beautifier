# frozen_string_literal: true

module SqlBeautifier
  class Join < Base
    option :keyword
    option :lateral, default: -> { false }
    option :table_reference
    option :trailing_sentinels, default: -> {}
    option :conditions, default: -> { [] }

    def self.parse(join_text, table_registry:)
      keyword, remaining_content = extract_keyword(join_text)
      return unless keyword && remaining_content

      remaining_content, lateral = TableReference.strip_lateral_prefix(remaining_content)

      on_keyword_position = Tokenizer.find_top_level_keyword(remaining_content, "on")

      if on_keyword_position
        table_text = remaining_content[0...on_keyword_position].strip
        condition_text = remaining_content[on_keyword_position..].delete_prefix("on").strip
        conditions = Tokenizer.split_top_level_conditions(condition_text)
      else
        table_text = remaining_content
        conditions = []
      end

      table_lookup_name = TableReference.derived_table_lookup_name_from(table_text) || Util.first_word(table_text)
      table_reference = table_registry.reference_for(table_lookup_name)
      return unless table_reference

      trailing_sentinels = extract_trailing_sentinels(table_text)

      new(keyword: keyword, lateral: lateral, table_reference: table_reference, trailing_sentinels: trailing_sentinels, conditions: conditions)
    end

    def self.extract_keyword(join_text)
      trimmed = join_text.strip

      Constants::JOIN_KEYWORDS_BY_LENGTH.each do |keyword|
        next unless trimmed.downcase.start_with?(keyword)

        remaining = trimmed[keyword.length..].strip
        return [keyword, remaining]
      end

      [nil, nil]
    end

    def self.extract_trailing_sentinels(text)
      text.scan(CommentParser::SENTINEL_PATTERN).map do |match|
        "#{CommentParser::SENTINEL_PREFIX}#{match[0]}#{CommentParser::SENTINEL_SUFFIX}"
      end.presence
    end

    def render(continuation_indent:, condition_indent:)
      rendered_table = @table_reference.render(trailing_sentinels: @trailing_sentinels)
      lateral_prefix = @lateral ? "lateral " : ""
      condition_indent_width = condition_indent.length
      lines = []

      if @conditions.any?
        first_condition = @conditions.first[1]
        formatted_first_condition = format_condition(first_condition, indent_width: condition_indent_width)
        lines << "#{continuation_indent}#{@keyword} #{lateral_prefix}#{rendered_table} on #{formatted_first_condition}"

        @conditions.drop(1).each do |conjunction, condition|
          formatted_condition = format_condition(condition, indent_width: condition_indent_width)
          lines << "#{condition_indent}#{conjunction} #{formatted_condition}"
        end
      else
        lines << "#{continuation_indent}#{@keyword} #{lateral_prefix}#{rendered_table}"
      end

      lines.join("\n")
    end

    private

    def format_condition(condition_text, indent_width:)
      condition_node = Condition.build(nil, condition_text)
      return condition_text if condition_node.leaf?

      condition_node.render(indent_width: indent_width)
    end
  end
end
