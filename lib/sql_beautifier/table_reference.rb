# frozen_string_literal: true

module SqlBeautifier
  class TableReference < Base
    option :name
    option :explicit_alias, default: -> {}
    option :assigned_alias, default: -> {}

    def self.parse(segment_text)
      table_specification = table_specification_text(segment_text)
      table_name = Util.first_word(table_specification)
      return unless table_name

      new(name: table_name, explicit_alias: extract_explicit_alias(table_specification))
    end

    def self.table_specification_text(segment_text)
      on_keyword_position = Tokenizer.find_top_level_keyword(segment_text, "on")
      return segment_text.strip unless on_keyword_position

      segment_text[0...on_keyword_position].strip
    end

    def self.extract_explicit_alias(table_specification)
      words = table_specification.strip.split(Constants::WHITESPACE_REGEX).grep_v(CommentParser::SENTINEL_PATTERN)
      return nil if words.length < 2

      if words[1] == "as"
        words[2]
      else
        words[1]
      end
    end

    def formatted_name
      Util.format_table_name(@name)
    end

    def assign_alias!(value)
      @assigned_alias = value
    end

    def alias_name
      @explicit_alias || @assigned_alias
    end

    def render(trailing_sentinels: nil)
      formatted = alias_name ? "#{formatted_name} #{alias_name}" : formatted_name
      trailing_sentinels&.any? ? "#{formatted} #{trailing_sentinels.join(' ')}" : formatted
    end
  end
end
