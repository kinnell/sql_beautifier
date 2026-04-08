# frozen_string_literal: true

module SqlBeautifier
  class CteDefinition < Base
    option :name
    option :body_sql
    option :column_list, default: -> {}
    option :materialization, default: -> {}

    def render_header
      formatted_name = @name.start_with?(Constants::DOUBLE_QUOTE) ? @name : Util.format_table_name(@name)
      header = +formatted_name
      header << " (#{@column_list})" if @column_list
      header << " #{Util.format_keyword('as')}"
      header << " #{format_materialization}" if @materialization
      header << " "
      header
    end

    def render_body(base_indent)
      indent_spaces = SqlBeautifier.config_for(:indent_spaces) || 4
      body_indent = base_indent + indent_spaces
      formatted = Formatter.new(@body_sql, depth: 0).call
      return "(#{@body_sql})" unless formatted

      indentation = Util.whitespace(body_indent)
      indented_lines = formatted.chomp.lines.map do |line|
        line.strip.empty? ? "\n" : "#{indentation}#{line}"
      end.join

      "(\n#{indented_lines}\n#{Util.whitespace(base_indent)})"
    end

    private

    def format_materialization
      return Util.format_keyword("materialized") if @materialization == "materialized"

      [Util.format_keyword("not"), Util.format_keyword("materialized")].join(" ")
    end
  end
end
