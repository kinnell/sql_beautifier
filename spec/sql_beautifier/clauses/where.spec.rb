# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Where do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a simple condition" do
      let(:value) { "active = true" }

      it "formats with keyword prefix" do
        expect(output).to eq("where   active = true")
      end
    end

    context "with multiple conditions" do
      let(:value) { "active = true and name = 'Alice'" }

      it "keeps conditions inline" do
        expect(output).to eq("where   active = true and name = 'Alice'")
      end
    end
  end
end
