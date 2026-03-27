# frozen_string_literal: true

RSpec.describe SqlBeautifier do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a whitespace-only string" do
      let(:value) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a valid query" do
      let(:value) { "SELECT id FROM users" }

      it "formats SQL" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end
    end
  end
end
