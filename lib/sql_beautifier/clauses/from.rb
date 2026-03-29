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
        primary_reference = @table_registry.reference_for(Util.first_word(primary_table_text))
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
        join_keyword_positions = find_all_join_keyword_positions(from_content)

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

      def find_all_join_keyword_positions(text)
        positions = []
        search_offset = 0

        while search_offset < text.length
          earliest_match = find_earliest_join_keyword(text, search_offset)
          break unless earliest_match

          positions << earliest_match
          search_offset = earliest_match[:position] + earliest_match[:keyword].length
        end

        positions
      end

      def find_earliest_join_keyword(text, search_offset)
        earliest_match = nil

        Constants::JOIN_KEYWORDS_BY_LENGTH.each do |keyword|
          remaining_text = text[search_offset..]
          keyword_position = Tokenizer.find_top_level_keyword(remaining_text, keyword)
          next unless keyword_position

          absolute_position = search_offset + keyword_position
          next if earliest_match && absolute_position >= earliest_match[:position]

          earliest_match = {
            position: absolute_position,
            keyword: keyword,
          }
        end

        earliest_match
      end
    end
  end
end
