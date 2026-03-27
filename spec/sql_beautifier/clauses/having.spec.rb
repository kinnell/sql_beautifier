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
  end
end
