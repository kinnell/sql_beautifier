# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::GroupBy do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single column" do
      let(:value) { "status" }

      it "formats with keyword" do
        expect(output).to eq("group by status")
      end
    end

    context "with multiple columns" do
      let(:value) { "status, department" }

      it "keeps columns inline" do
        expect(output).to eq("group by status, department")
      end
    end

    context "with a function expression" do
      let(:value) { "date_trunc('month', created_at), status" }

      it "keeps the function expression intact" do
        expect(output).to eq("group by date_trunc('month', created_at), status")
      end
    end

    context "with three columns" do
      let(:value) { "year, quarter, department" }

      it "keeps all columns inline" do
        expect(output).to eq("group by year, quarter, department")
      end
    end

    context "with extra whitespace" do
      let(:value) { "  status , department  " }

      it "strips surrounding whitespace" do
        expect(output).to eq("group by status , department")
      end
    end
  end
end
