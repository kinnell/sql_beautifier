# frozen_string_literal: true

module SqlBeautifier
  class Formatter
    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      return unless @value.present?

      @normalized_value = Normalizer.call(@value)
      return unless @normalized_value.present?

      first_clause_position = Tokenizer.first_clause_position(@normalized_value)
      return "#{@normalized_value}\n" if first_clause_position.nil? || first_clause_position.positive?

      @clauses = Tokenizer.split_into_clauses(@normalized_value)
      @table_registry = TableRegistry.new(@clauses[:from]) if @clauses[:from].present?
      @parts = []

      append_clause!(:select, Clauses::Select)
      append_from_clause!
      append_clause!(:where, Clauses::Where)
      append_clause!(:group_by, Clauses::GroupBy)
      append_clause!(:having, Clauses::Having)
      append_clause!(:order_by, Clauses::OrderBy)
      append_clause!(:limit, Clauses::Limit)

      output = @parts.join("\n\n")
      return "#{@normalized_value}\n" if output.empty?

      output = @table_registry.apply_aliases(output) if @table_registry
      "#{output}\n"
    end

    private

    def append_clause!(clause_key, formatter_class)
      value = @clauses[clause_key]
      return unless value.present?

      @parts << formatter_class.call(value)
    end

    def append_from_clause!
      value = @clauses[:from]
      return unless value.present?

      @parts << Clauses::From.call(value, table_registry: @table_registry)
    end
  end
end
