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

    context "with direction" do
      let(:value) { "created_at desc" }

      it "preserves sort direction" do
        expect(output).to eq("order by created_at desc")
      end
    end
  end
end
