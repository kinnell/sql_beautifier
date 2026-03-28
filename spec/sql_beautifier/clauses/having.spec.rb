# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Having do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a simple condition" do
      let(:value) { "count(*) > 5" }

      it "formats with keyword prefix" do
        expect(output).to eq("having  count(*) > 5")
      end
    end

    context "with AND conditions" do
      let(:value) { "count(*) > 5 and sum(total) > 1000" }

      it "formats each condition on its own line" do
        expect(output).to eq(<<~SQL.chomp)
          having  count(*) > 5
                  and sum(total) > 1000
        SQL
      end
    end

    context "with OR conditions" do
      let(:value) { "count(*) > 5 or sum(total) > 1000" }

      it "formats each condition on its own line" do
        expect(output).to eq(<<~SQL.chomp)
          having  count(*) > 5
                  or sum(total) > 1000
        SQL
      end
    end

    context "with mixed AND/OR conditions" do
      let(:value) { "count(*) > 5 and sum(total) > 1000 or avg(price) < 10" }

      it "formats each condition with its conjunction" do
        expect(output).to eq(<<~SQL.chomp)
          having  count(*) > 5
                  and sum(total) > 1000
                  or avg(price) < 10
        SQL
      end
    end

    context "with three AND conditions" do
      let(:value) { "count(*) > 5 and sum(total) > 1000 and min(price) > 0" }

      it "formats each condition on its own line" do
        expect(output).to eq(<<~SQL.chomp)
          having  count(*) > 5
                  and sum(total) > 1000
                  and min(price) > 0
        SQL
      end
    end

    context "with a parenthesized group" do
      let(:value) { "count(*) > 5 and (sum(total) > 1000 or avg(price) < 10)" }

      it "expands the group to multiple lines" do
        expect(output).to eq(<<~SQL.chomp)
          having  count(*) > 5
                  and (
                      sum(total) > 1000
                      or avg(price) < 10
                  )
        SQL
      end
    end
  end
end
