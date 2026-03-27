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

    context "with a placeholder parameter" do
      let(:value) { "$1" }

      it "formats with keyword" do
        expect(output).to eq("limit $1")
      end
    end

    context "with a large number" do
      let(:value) { "1000" }

      it "formats with keyword" do
        expect(output).to eq("limit 1000")
      end
    end

    context "with extra whitespace" do
      let(:value) { "  50  " }

      it "strips surrounding whitespace" do
        expect(output).to eq("limit 50")
      end
    end
  end
end
