# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Select do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single column" do
      let(:value) { "id" }

      it "formats on one line" do
        expect(output).to eq("select  id")
      end
    end

    context "with multiple columns" do
      let(:value) { "id, name, email" }

      it "places each on its own line" do
        expect(output).to eq(<<~SQL.chomp)
          select  id,
                  name,
                  email
        SQL
      end
    end

    context "with function calls" do
      let(:value) { "id, coalesce(name, 'unknown'), email" }

      it "keeps function arguments together" do
        expect(output).to eq(<<~SQL.chomp)
          select  id,
                  coalesce(name, 'unknown'),
                  email
        SQL
      end
    end
  end
end
