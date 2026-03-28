# frozen_string_literal: true

module SqlBeautifier
  module Clauses
    class From < Base
      KEYWORD = "from"

      def self.call(value, table_registry:)
        new(value, table_registry: table_registry).call
      end

      def initialize(value, table_registry:)
        super(value)
        @table_registry = table_registry
      end

      def call
        @lines = []

        join_parts = split_join_parts
        primary_table_text = join_parts.shift.strip
        formatted_primary_table_name = format_table_with_alias(primary_table_text)
        add_line!("#{keyword_prefix}#{formatted_primary_table_name}")

        join_parts.each { |join_part| format_join_part(join_part) }

        @lines.join("\n")
      end

      private

      def add_line!(line)
        @lines << line
      end

      def join_condition_indentation
        Util.whitespace(SqlBeautifier.config_for(:keyword_column_width) + 4)
      end

      def format_join_part(join_part)
        join_keyword, remaining_join_content = extract_join_keyword(join_part)
        return unless join_keyword && remaining_join_content

        on_keyword_position = Tokenizer.find_top_level_keyword(remaining_join_content, "on")

        if on_keyword_position
          format_join_with_conditions(join_keyword, remaining_join_content, on_keyword_position)
        else
          formatted_table_name = format_table_with_alias(remaining_join_content)
          add_line!("#{continuation_indent}#{join_keyword} #{formatted_table_name}")
        end
      end

      def format_join_with_conditions(join_keyword, join_content, on_keyword_position)
        table_text = join_content[0...on_keyword_position].strip
        condition_text = join_content[on_keyword_position..].delete_prefix("on").strip
        on_conditions = Tokenizer.split_top_level_conditions(condition_text)

        formatted_table_name = format_table_with_alias(table_text)
        first_condition = on_conditions.first[1]
        add_line!("#{continuation_indent}#{join_keyword} #{formatted_table_name} on #{first_condition}")

        on_conditions.drop(1).each do |conjunction, additional_condition|
          add_line!("#{join_condition_indentation}#{conjunction} #{additional_condition}")
        end
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

      def extract_join_keyword(join_part)
        trimmed_join_text = join_part.strip

        Constants::JOIN_KEYWORDS_BY_LENGTH.each do |keyword|
          next unless trimmed_join_text.downcase.start_with?(keyword)

          remaining_join_content = trimmed_join_text[keyword.length..].strip

          return [keyword, remaining_join_content]
        end

        [nil, nil]
      end

      def format_table_with_alias(table_text)
        table_name = Util.first_word(table_text)
        formatted_table_name = Util.format_table_name(table_name)
        table_alias = @table_registry.alias_for(table_name)
        trailing_sentinels = extract_trailing_sentinels(table_text)

        formatted = table_alias ? "#{formatted_table_name} #{table_alias}" : formatted_table_name
        trailing_sentinels.empty? ? formatted : "#{formatted} #{trailing_sentinels}"
      end

      def extract_trailing_sentinels(text)
        sentinels = text.scan(CommentStripper::SENTINEL_PATTERN).map { |match| "#{CommentStripper::SENTINEL_PREFIX}#{match[0]}#{CommentStripper::SENTINEL_SUFFIX}" }
        sentinels.join(" ")
      end
    end
  end
end
