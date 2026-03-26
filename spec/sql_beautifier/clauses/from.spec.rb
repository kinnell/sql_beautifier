# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::From do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single table" do
      let(:value) { "users" }

      it "formats with keyword prefix" do
        expect(output).to eq("from    users")
      end
    end

    context "with extra whitespace" do
      let(:value) { "  users  " }

      it "strips whitespace" do
        expect(output).to eq("from    users")
      end
    end
  end
end
