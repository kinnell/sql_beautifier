# frozen_string_literal: true

module SqlBeautifier
  class CreateTableAs < Base
    MODIFIERS = %w[temp temporary unlogged local].freeze
    WITH_DATA_SUFFIX_REGEX = %r{\s+(with\s+(?:no\s+)?data)\s*\z}i

    option :modifier, default: -> {}
    option :if_not_exists, type: Types::Bool
    option :table_name
    option :body_sql
    option :suffix, default: -> {}
    option :depth, default: -> { 0 }

    def self.parse(normalized_sql, depth: 0)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("create")

      scanner.skip_past_keyword!("create")
      modifier = detect_modifier(scanner)
      scanner.skip_past_keyword!(modifier) if modifier

      return nil unless scanner.keyword_at?("table")

      scanner.skip_past_keyword!("table")

      if_not_exists = detect_if_not_exists?(scanner)
      skip_past_if_not_exists!(scanner) if if_not_exists

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!
      return nil unless scanner.keyword_at?("as")

      scanner.skip_past_keyword!("as")

      body_sql, suffix = extract_body(normalized_sql, scanner.position)
      return nil unless body_sql

      new(modifier: modifier, if_not_exists: if_not_exists, table_name: table_name, body_sql: body_sql, suffix: suffix, depth: depth)
    end

    def self.detect_modifier(scanner)
      MODIFIERS.detect { |modifier| scanner.keyword_at?(modifier) }
    end

    def self.detect_if_not_exists?(scanner)
      return false unless scanner.keyword_at?("if")

      probe = Scanner.new(scanner.source, position: scanner.position)
      probe.skip_past_keyword!("if")
      return false unless probe.keyword_at?("not")

      probe.skip_past_keyword!("not")
      probe.keyword_at?("exists")
    end

    def self.skip_past_if_not_exists!(scanner)
      scanner.skip_past_keyword!("if")
      scanner.skip_past_keyword!("not")
      scanner.skip_past_keyword!("exists")
    end

    def self.extract_body(sql, position)
      scanner = Scanner.new(sql, position: position)
      scanner.skip_whitespace!
      return nil if scanner.finished?

      if scanner.current_char == Constants::OPEN_PARENTHESIS
        closing = scanner.find_matching_parenthesis(scanner.position)
        return nil unless closing

        body = sql[(scanner.position + 1)...closing].strip
        suffix = sql[(closing + 1)..].strip.presence
        [body, suffix]
      else
        extract_unparenthesized_body(sql[scanner.position..].strip)
      end
    end

    def self.extract_unparenthesized_body(raw_body)
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

    def render
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      formatted = Formatter.new(@body_sql, depth: 0).call
      return "#{preamble}\n" unless formatted

      indentation = Util.whitespace(indent_spaces)
      indented_lines = formatted.chomp.lines.map do |line|
        line.strip.empty? ? "\n" : "#{indentation}#{line}"
      end.join

      formatted_suffix = @suffix ? " #{format_suffix}" : ""
      "#{preamble} (\n#{indented_lines}\n)#{formatted_suffix}\n"
    end

    private

    def preamble
      parts = [Util.format_keyword("create")]
      parts << Util.format_keyword(@modifier) if @modifier
      parts << Util.format_keyword("table")
      parts << "#{Util.format_keyword('if')} #{Util.format_keyword('not')} #{Util.format_keyword('exists')}" if @if_not_exists
      parts << Util.format_table_name(@table_name)
      parts << Util.format_keyword("as")
      parts.join(" ")
    end

    def format_suffix
      @suffix.strip.split(Constants::WHITESPACE_REGEX).map { |word| Util.format_keyword(word) }.join(" ")
    end
  end
end
