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

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(SqlBeautifier::Configuration)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.keyword_column_width = 12
      end

      expect(described_class.configuration.keyword_column_width).to eq(12)
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration with a fresh instance" do
      original = described_class.configuration
      described_class.configure { |config| config.keyword_column_width = 12 }

      described_class.reset_configuration!

      expect(described_class.configuration).not_to equal(original)
      expect(described_class.configuration.keyword_column_width).to eq(8)
    end
  end
end
