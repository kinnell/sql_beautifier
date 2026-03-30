# frozen_string_literal: true

module SqlBeautifier
  class TableReference < Base
    option :name
    option :explicit_alias, default: -> {}
    option :assigned_alias, default: -> {}
    option :derived_table_expression, default: -> {}

    def self.parse(segment_text)
      table_specification = table_specification_text(segment_text)
      stripped_specification = table_specification.strip

      return parse_derived_table(stripped_specification) if stripped_specification.start_with?(Constants::OPEN_PARENTHESIS)

      table_name = Util.first_word(stripped_specification)
      return unless table_name

      new(name: table_name, explicit_alias: extract_explicit_alias(stripped_specification))
    end

    def self.parse_derived_table(table_specification)
      closing_position = Scanner.new(table_specification).find_matching_parenthesis(0)
      return unless closing_position

      expression = table_specification[0..closing_position]
      remaining = table_specification[(closing_position + 1)..].strip
      derived_alias = extract_derived_table_alias(remaining)

      new(
        name: derived_alias || expression,
        explicit_alias: derived_alias,
        derived_table_expression: expression
      )
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

    def self.derived_table_lookup_name_from(text)
      stripped_text = text.strip
      return unless stripped_text.start_with?(Constants::OPEN_PARENTHESIS)

      closing_position = Scanner.new(stripped_text).find_matching_parenthesis(0)
      return unless closing_position

      expression = stripped_text[0..closing_position]
      remaining_text = stripped_text[(closing_position + 1)..].strip
      derived_alias = extract_derived_table_alias(remaining_text)

      derived_alias || expression
    end

    def self.extract_derived_table_alias(remaining_text)
      return if remaining_text.empty?

      words = remaining_text.split(Constants::WHITESPACE_REGEX)

      if words.first&.downcase == "as"
        words[1]
      else
        words.first
      end
    end

    def derived_table?
      @derived_table_expression.present?
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
      formatted = begin
        if derived_table?
          alias_name ? "#{@derived_table_expression} #{alias_name}" : @derived_table_expression
        else
          alias_name ? "#{formatted_name} #{alias_name}" : formatted_name
        end
      end

      trailing_sentinels&.any? ? "#{formatted} #{trailing_sentinels.join(' ')}" : formatted
    end
  end
end
