# frozen_string_literal: true

module SqlBeautifier
  class DropTable < Base
    option :table_name
    option :if_exists, type: Types::Bool

    def self.parse(normalized_sql, **)
      scanner = Scanner.new(normalized_sql)
      return nil unless scanner.keyword_at?("drop")

      scanner.skip_past_keyword!("drop")
      return nil unless scanner.keyword_at?("table")

      scanner.skip_past_keyword!("table")

      if_exists = false

      if scanner.keyword_at?("if")
        return nil unless detect_if_exists?(scanner)

        skip_past_if_exists!(scanner)
        if_exists = true
      end

      table_name = scanner.read_identifier!
      return nil unless table_name

      scanner.skip_whitespace!
      return nil unless scanner.finished?

      new(table_name: table_name, if_exists: if_exists)
    end

    def self.detect_if_exists?(scanner)
      probe = Scanner.new(scanner.source, position: scanner.position)
      probe.skip_past_keyword!("if")
      probe.keyword_at?("exists")
    end

    def self.skip_past_if_exists!(scanner)
      scanner.skip_past_keyword!("if")
      scanner.skip_past_keyword!("exists")
    end

    private_class_method :detect_if_exists?, :skip_past_if_exists!

    def render
      parts = [Util.format_keyword("drop"), Util.format_keyword("table")]
      parts << "#{Util.format_keyword('if')} #{Util.format_keyword('exists')}" if @if_exists
      parts << Util.format_table_name(@table_name)

      "#{parts.join(' ')}\n"
    end
  end
end
