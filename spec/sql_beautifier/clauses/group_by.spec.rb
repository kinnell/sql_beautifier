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
  end
end
