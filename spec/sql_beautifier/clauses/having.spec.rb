# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Having do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a simple condition" do
      let(:value) { "count(*) > 5" }

      it "formats with keyword prefix" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          having  count(*) > 5
        SQL
      end
    end

    context "with AND conditions" do
      let(:value) { "count(*) > 5 and sum(total) > 1000" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          having  count(*) > 5
                  and sum(total) > 1000
        SQL
      end
    end

    context "with a set of parentheses around a single condition" do
      let(:value) { "(count(*) > 5)" }

      it "formats without the parentheses" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          having  count(*) > 5
        SQL
      end
    end

    context "with multiple sets of parentheses around a single condition" do
      let(:value) { "((count(*) > 5))" }

      it "formats without the parentheses" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          having  count(*) > 5
        SQL
      end
    end

    context "with a set of parentheses around multiple conditions" do
      let(:value) { "((count(*) > 5) and (sum(total) > 1000))" }

      it "formats without the parentheses" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          having  count(*) > 5
                  and sum(total) > 1000
        SQL
      end
    end
  end
end
