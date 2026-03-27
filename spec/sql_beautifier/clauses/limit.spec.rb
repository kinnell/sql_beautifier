# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Limit do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a numeric limit" do
      let(:value) { "10" }

      it "formats with keyword" do
        expect(output).to eq("limit 10")
      end
    end
  end
end
