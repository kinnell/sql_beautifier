# frozen_string_literal: true

RSpec.describe SqlBeautifier do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "when the value is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is an empty string" do
      let(:value) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is a whitespace-only string" do
      let(:value) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is a valid query" do
      let(:value) { "SELECT id FROM users" }

      it "formats SQL" do
        expect(output).to include("select  id")
        expect(output).to include("from    users")
      end
    end
  end
end
