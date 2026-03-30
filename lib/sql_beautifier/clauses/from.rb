# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class From < Base
      KEYWORD = "from"

      def self.call(...)
        new(...).call
      end

      def initialize(value, table_registry:)
        super(value)

        @table_registry = table_registry
      end

      def call
        join_parts = split_join_parts
        primary_table_text = join_parts.shift.strip
        primary_lookup_name = TableReference.derived_table_lookup_name_from(primary_table_text) || Util.first_word(primary_table_text)
        primary_reference = @table_registry.reference_for(primary_lookup_name)
        trailing_sentinels = Join.extract_trailing_sentinels(primary_table_text)

        lines = []
        lines << "#{keyword_prefix}#{primary_reference.render(trailing_sentinels: trailing_sentinels)}"

        join_parts.each do |join_text|
          join = Join.parse(join_text, table_registry: @table_registry)
          next unless join

          lines << join.render(continuation_indent: continuation_indent, condition_indent: join_condition_indentation)
        end

        lines.join("\n")
      end

      private

      def join_condition_indentation
        Util.whitespace(SqlBeautifier.config_for(:keyword_column_width) + 4)
      end

      def split_join_parts
        from_content = @value.strip
        join_keyword_positions = Tokenizer.find_all_top_level_join_positions(from_content)

        return [from_content] if join_keyword_positions.empty?

        parts = [from_content[0...join_keyword_positions.first[:position]]]

        join_keyword_positions.each_with_index do |join_info, index|
          end_position = begin
            if index + 1 < join_keyword_positions.length
              join_keyword_positions[index + 1][:position]
            else
              from_content.length
            end
          end

          parts << from_content[join_info[:position]...end_position]
        end

        parts
      end
    end
  end
end
