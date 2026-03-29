# frozen_string_literal: true

RSpec.describe SqlBeautifier::Configuration do
  let(:configuration) { SqlBeautifier::Configuration.new }
  let(:default_value) { SqlBeautifier::Configuration::DEFAULTS.fetch(config_key) }

  describe "DEFAULTS" do
    context "when :config_key is :keyword_case" do
      let(:config_key) { :keyword_case }

      it "defines :keyword_case as :lower" do
        expect(default_value).to eq(:lower)
      end
    end

    context "when :config_key is :keyword_column_width" do
      let(:config_key) { :keyword_column_width }

      it "defines :keyword_column_width as 8" do
        expect(default_value).to eq(8)
      end
    end

    context "when :config_key is :indent_spaces" do
      let(:config_key) { :indent_spaces }

      it "defines :indent_spaces as 4" do
        expect(default_value).to eq(4)
      end
    end

    context "when :config_key is :clause_spacing_mode" do
      let(:config_key) { :clause_spacing_mode }

      it "defines :clause_spacing_mode as :compact" do
        expect(default_value).to eq(:compact)
      end
    end

    context "when :config_key is :table_name_format" do
      let(:config_key) { :table_name_format }

      it "defines :table_name_format as :pascal_case" do
        expect(default_value).to eq(:pascal_case)
      end
    end

    context "when :config_key is :inline_group_threshold" do
      let(:config_key) { :inline_group_threshold }

      it "defines :inline_group_threshold as 0" do
        expect(default_value).to eq(0)
      end
    end

    context "when :config_key is :alias_strategy" do
      let(:config_key) { :alias_strategy }

      it "defines :alias_strategy as :initials" do
        expect(default_value).to eq(:initials)
      end
    end

    context "when :config_key is :trailing_semicolon" do
      let(:config_key) { :trailing_semicolon }

      it "defines :trailing_semicolon as true" do
        expect(default_value).to eq(true)
      end
    end

    context "when :config_key is :removable_comment_types" do
      let(:config_key) { :removable_comment_types }

      it "defines :removable_comment_types as :none" do
        expect(default_value).to eq(:none)
      end
    end
  end

  describe "#reset!" do
    before do
      configuration.keyword_column_width = 12
      configuration.keyword_case = :upper
      configuration.indent_spaces = 6
      configuration.clause_spacing_mode = :spacious
      configuration.removable_comment_types = :all

      configuration.reset!
    end

    it "restores defaults after mutation" do
      expect(configuration.keyword_column_width).to eq(8)
      expect(configuration.keyword_case).to eq(:lower)
      expect(configuration.indent_spaces).to eq(4)
      expect(configuration.clause_spacing_mode).to eq(:compact)
      expect(configuration.removable_comment_types).to eq(:none)
    end
  end
end
