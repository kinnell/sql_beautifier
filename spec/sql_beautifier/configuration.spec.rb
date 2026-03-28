# frozen_string_literal: true

RSpec.describe SqlBeautifier::Configuration do
  subject(:configuration) { described_class.new }

  describe "DEFAULTS" do
    it "defines :keyword_case as :lower" do
      expect(described_class::DEFAULTS[:keyword_case]).to eq(:lower)
    end

    it "defines :keyword_column_width as 8" do
      expect(described_class::DEFAULTS[:keyword_column_width]).to eq(8)
    end

    it "defines :indent_spaces as 4" do
      expect(described_class::DEFAULTS[:indent_spaces]).to eq(4)
    end

    it "defines :clause_spacing_mode as :compact" do
      expect(described_class::DEFAULTS[:clause_spacing_mode]).to eq(:compact)
    end

    it "defines :table_name_format as :pascal_case" do
      expect(described_class::DEFAULTS[:table_name_format]).to eq(:pascal_case)
    end

    it "defines :inline_group_threshold as 0" do
      expect(described_class::DEFAULTS[:inline_group_threshold]).to eq(0)
    end

    it "defines :alias_strategy as :initials" do
      expect(described_class::DEFAULTS[:alias_strategy]).to eq(:initials)
    end

    it "defines :trailing_semicolon as true" do
      expect(described_class::DEFAULTS[:trailing_semicolon]).to eq(true)
    end

    it "defines :removable_comment_types as :none" do
      expect(described_class::DEFAULTS[:removable_comment_types]).to eq(:none)
    end
  end

  describe "#reset!" do
    it "restores defaults after mutation" do
      configuration.keyword_column_width = 12
      configuration.keyword_case = :upper
      configuration.indent_spaces = 6
      configuration.clause_spacing_mode = :spacious
      configuration.removable_comment_types = :all

      configuration.reset!

      expect(configuration.keyword_column_width).to eq(8)
      expect(configuration.keyword_case).to eq(:lower)
      expect(configuration.indent_spaces).to eq(4)
      expect(configuration.clause_spacing_mode).to eq(:compact)
      expect(configuration.removable_comment_types).to eq(:none)
    end
  end
end
