# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::OrderBy do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single column" do
      let(:value) { "name" }

      it "formats with keyword" do
        expect(output).to eq("order by name")
      end
    end

    context "with DESC direction" do
      let(:value) { "created_at desc" }

      it "preserves sort direction" do
        expect(output).to eq("order by created_at desc")
      end
    end

    context "with ASC direction" do
      let(:value) { "name asc" }

      it "preserves sort direction" do
        expect(output).to eq("order by name asc")
      end
    end

    context "with multiple columns" do
      let(:value) { "department, name asc, created_at desc" }

      it "keeps all columns inline" do
        expect(output).to eq("order by department, name asc, created_at desc")
      end
    end

    context "with NULLS FIRST" do
      let(:value) { "name asc nulls first" }

      it "preserves the nulls ordering" do
        expect(output).to eq("order by name asc nulls first")
      end
    end

    context "with NULLS LAST" do
      let(:value) { "created_at desc nulls last" }

      it "preserves the nulls ordering" do
        expect(output).to eq("order by created_at desc nulls last")
      end
    end

    context "with extra whitespace" do
      let(:value) { "  name asc  " }

      it "strips surrounding whitespace" do
        expect(output).to eq("order by name asc")
      end
    end

    context "with a function expression" do
      let(:value) { "lower(name) asc" }

      it "keeps the function expression intact" do
        expect(output).to eq("order by lower(name) asc")
      end
    end
  end
end
