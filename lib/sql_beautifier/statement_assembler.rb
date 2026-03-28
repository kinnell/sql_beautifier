# frozen_string_literal: true

module SqlBeautifier
  class StatementAssembler
    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      removable_types = SqlBeautifier.config_for(:removable_comment_types)
      comment_result = CommentStripper.call(@value, removable_types)

      statements = StatementSplitter.split(comment_result.stripped_sql)
      formatted_statements = statements.filter_map do |statement|
        Formatter.call(statement)&.chomp
      end
      return if formatted_statements.empty?

      trailing_semicolon = SqlBeautifier.config_for(:trailing_semicolon)
      separator = trailing_semicolon ? ";\n\n" : "\n\n"
      terminator = trailing_semicolon ? ";\n" : "\n"

      output = formatted_statements.join(separator) + terminator
      CommentRestorer.call(output, comment_result.comment_map)
    end
  end
end
