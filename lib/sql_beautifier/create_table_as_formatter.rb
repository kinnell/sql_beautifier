# frozen_string_literal: true

module SqlBeautifier
  module CreateTableAsFormatter
    MODIFIERS = %w[
      temp
      temporary
      unlogged
      local
    ].freeze

    WITH_DATA_SUFFIX_REGEX = %r{\s+(with\s+(?:no\s+)?data)\s*\z}i

    module_function

    def format(normalized_sql, _args = {})
      return nil unless create_table_as_query?(normalized_sql)

      parsed = parse(normalized_sql)
      return nil unless parsed

      format_statement(parsed[:preamble], parsed[:body], parsed[:suffix])
    end

    def create_table_as_query?(sql)
      Tokenizer.keyword_at?(sql, 0, "create")
    end

    def parse(sql)
      position = 0
      return nil unless Tokenizer.keyword_at?(sql, position, "create")

      position = skip_past_keyword(sql, position, "create")

      modifier = detect_modifier(sql, position)
      position = skip_past_keyword(sql, position, modifier) if modifier

      return nil unless Tokenizer.keyword_at?(sql, position, "table")

      position = skip_past_keyword(sql, position, "table")

      if_not_exists = detect_if_not_exists?(sql, position)
      position = skip_past_if_not_exists(sql, position) if if_not_exists

      table_name, position = read_identifier(sql, position)
      return nil unless table_name

      position = skip_whitespace(sql, position)
      return nil unless Tokenizer.keyword_at?(sql, position, "as")

      position = skip_past_keyword(sql, position, "as")

      result = extract_body(sql, position)
      return nil unless result

      body_sql, suffix = result
      return nil unless body_sql

      preamble = build_preamble(modifier, if_not_exists, table_name)
      { preamble: preamble, body: body_sql, suffix: suffix }
    end

    def detect_modifier(sql, position)
      MODIFIERS.detect { |modifier| Tokenizer.keyword_at?(sql, position, modifier) }
    end

    def detect_if_not_exists?(sql, position)
      Tokenizer.keyword_at?(sql, position, "if") && Tokenizer.keyword_at?(sql, skip_past_keyword(sql, position, "if"), "not") && Tokenizer.keyword_at?(sql, skip_past_keyword(sql, skip_past_keyword(sql, position, "if"), "not"), "exists")
    end

    def skip_past_if_not_exists(sql, position)
      position = skip_past_keyword(sql, position, "if")
      position = skip_past_keyword(sql, position, "not")
      skip_past_keyword(sql, position, "exists")
    end

    def extract_body(sql, position)
      position = skip_whitespace(sql, position)
      return nil if position >= sql.length

      if sql[position] == Constants::OPEN_PARENTHESIS
        closing = Tokenizer.find_matching_parenthesis(sql, position)
        return nil unless closing

        body = sql[(position + 1)...closing].strip
        suffix = sql[(closing + 1)..].strip.presence
        [body, suffix]
      else
        extract_unparenthesized_body(sql[position..].strip)
      end
    end

    def extract_unparenthesized_body(raw_body)
      return nil unless raw_body.present?

      match = raw_body.match(WITH_DATA_SUFFIX_REGEX)

      if match
        body = raw_body[0...match.begin(0)].strip
        return nil unless body.present?

        [body, match[1]]
      else
        [raw_body, nil]
      end
    end

    def build_preamble(modifier, if_not_exists, table_name)
      parts = [Util.format_keyword("create")]
      parts << Util.format_keyword(modifier) if modifier
      parts << Util.format_keyword("table")
      parts << "#{Util.format_keyword('if')} #{Util.format_keyword('not')} #{Util.format_keyword('exists')}" if if_not_exists
      parts << Util.format_table_name(table_name)
      parts << Util.format_keyword("as")
      parts.join(" ")
    end

    def format_statement(preamble, body_sql, suffix)
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      formatted = Formatter.new(body_sql, depth: 0).call
      return "#{preamble}\n" unless formatted

      indentation = Util.whitespace(indent_spaces)
      indented_lines = formatted.chomp.lines.map { |line| line.strip.empty? ? "\n" : "#{indentation}#{line}" }.join

      formatted_suffix = suffix ? " #{format_suffix(suffix)}" : ""
      "#{preamble} (\n#{indented_lines}\n)#{formatted_suffix}\n"
    end

    def format_suffix(suffix)
      suffix.strip.split(%r{\s+}).map { |word| Util.format_keyword(word) }.join(" ")
    end

    def read_identifier(sql, position)
      position = skip_whitespace(sql, position)
      return nil if position >= sql.length

      if sql[position] == Constants::DOUBLE_QUOTE
        start = position
        position += 1

        while position < sql.length
          if sql[position] == Constants::DOUBLE_QUOTE
            if position + 1 < sql.length && sql[position + 1] == Constants::DOUBLE_QUOTE
              position += 2
              next
            end

            position += 1
            break
          end

          position += 1
        end

        return nil unless position <= sql.length && sql[position - 1] == Constants::DOUBLE_QUOTE

        return [sql[start...position], position]
      end

      start = position
      position += 1 while position < sql.length && sql[position] =~ Tokenizer::IDENTIFIER_CHARACTER
      return nil if position == start

      [sql[start...position], position]
    end

    def skip_whitespace(sql, position)
      position += 1 while position < sql.length && sql[position] =~ Constants::WHITESPACE_CHARACTER_REGEX
      position
    end

    def skip_past_keyword(sql, position, keyword)
      skip_whitespace(sql, position + keyword.length)
    end
  end
end
