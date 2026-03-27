# frozen_string_literal: true

RSpec.describe SqlBeautifier::Util do
  ############################################################################
  ## .upper_pascal_case
  ############################################################################

  describe ".upper_pascal_case" do
    let(:output) { described_class.upper_pascal_case(value) }

    context "with an empty string" do
      let(:value) { "" }

      it "returns an empty string" do
        expect(output).to eq("")
      end
    end

    context "with a simple name" do
      let(:value) { "users" }

      it "capitalizes the name" do
        expect(output).to eq("Users")
      end
    end

    context "with an underscore-separated name" do
      let(:value) { "active_storage_blobs" }

      it "capitalizes each segment" do
        expect(output).to eq("Active_Storage_Blobs")
      end
    end

    context "with a single-character name" do
      let(:value) { "a" }

      it "capitalizes the character" do
        expect(output).to eq("A")
      end
    end

    context "with already-capitalized input" do
      let(:value) { "Users" }

      it "returns unchanged" do
        expect(output).to eq("Users")
      end
    end

    context "with mixed-case input" do
      let(:value) { "userSessions" }

      it "downcases segments after the first character" do
        expect(output).to eq("Usersessions")
      end
    end
  end

  ############################################################################
  ## .first_word
  ############################################################################

  describe ".first_word" do
    let(:output) { described_class.first_word(value) }

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

    context "with a multi-word string" do
      let(:value) { "users inner join" }

      it "returns the first word" do
        expect(output).to eq("users")
      end
    end

    context "with leading whitespace" do
      let(:value) { "  orders left join" }

      it "strips whitespace and returns the first word" do
        expect(output).to eq("orders")
      end
    end

    context "with no spaces" do
      let(:value) { "users" }

      it "returns the full text" do
        expect(output).to eq("users")
      end
    end

    context "with tab-separated words" do
      let(:value) { "users\tjoin" }

      it "returns the first word" do
        expect(output).to eq("users")
      end
    end
  end

  ############################################################################
  ## .strip_outer_parentheses
  ############################################################################

  describe ".strip_outer_parentheses" do
    let(:output) { described_class.strip_outer_parentheses(value) }

    context "with an empty string" do
      let(:value) { "" }

      it "returns an empty string" do
        expect(output).to eq("")
      end
    end

    context "with empty parentheses" do
      let(:value) { "()" }

      it "returns an empty string" do
        expect(output).to eq("")
      end
    end

    context "with outer parentheses and inner whitespace" do
      let(:value) { "( a = 1 )" }

      it "removes parentheses and strips whitespace" do
        expect(output).to eq("a = 1")
      end
    end

    context "with text not starting with a parenthesis" do
      let(:value) { "a = 1" }

      it "returns unchanged" do
        expect(output).to eq("a = 1")
      end
    end

    context "with text not ending with a parenthesis" do
      let(:value) { "(a = 1" }

      it "returns unchanged" do
        expect(output).to eq("(a = 1")
      end
    end

    context "with surrounding whitespace" do
      let(:value) { "  (a = 1)  " }

      it "strips whitespace before removing parentheses" do
        expect(output).to eq("a = 1")
      end
    end

    context "with nested parentheses" do
      let(:value) { "((a = 1))" }

      it "only removes one layer" do
        expect(output).to eq("(a = 1)")
      end
    end
  end

  ############################################################################
  ## .double_quote_string
  ############################################################################

  describe ".double_quote_string" do
    let(:output) { described_class.double_quote_string(value) }

    context "with nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "wraps in double quotes" do
        expect(output).to eq('""')
      end
    end

    context "with a plain value" do
      let(:value) { "column" }

      it "wraps in double quotes" do
        expect(output).to eq('"column"')
      end
    end

    context "with existing double quotes in the value" do
      let(:value) { 'double "quotes"' }

      it "does not escape them" do
        expect(output).to eq('"double "quotes""')
      end
    end
  end

  ############################################################################
  ## .escape_double_quote
  ############################################################################

  describe ".escape_double_quote" do
    let(:output) { described_class.escape_double_quote(value) }

    context "with nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "returns unchanged" do
        expect(output).to eq("")
      end
    end

    context "with a single double quote" do
      let(:value) { 'a"b' }

      it "escapes the double quote" do
        expect(output).to eq('a""b')
      end
    end

    context "with multiple double quotes" do
      let(:value) { '"a"b"' }

      it "escapes all double quotes" do
        expect(output).to eq('""a""b""')
      end
    end

    context "with no double quotes" do
      let(:value) { "abc" }

      it "returns unchanged" do
        expect(output).to eq("abc")
      end
    end
  end

  ############################################################################
  ## .keyword_padding
  ############################################################################

  describe ".keyword_padding" do
    context "with default configuration" do
      it "pads 'select' to 8 characters" do
        expect(described_class.keyword_padding("select")).to eq("select  ")
      end

      it "pads 'from' to 8 characters" do
        expect(described_class.keyword_padding("from")).to eq("from    ")
      end

      it "pads 'where' to 8 characters" do
        expect(described_class.keyword_padding("where")).to eq("where   ")
      end

      it "pads 'having' to 8 characters" do
        expect(described_class.keyword_padding("having")).to eq("having  ")
      end

      it "gives 'order by' a single trailing space" do
        expect(described_class.keyword_padding("order by")).to eq("order by ")
      end

      it "gives 'group by' a single trailing space" do
        expect(described_class.keyword_padding("group by")).to eq("group by ")
      end
    end

    context "with custom :keyword_column_width" do
      before { SqlBeautifier.configure { |config| config.keyword_column_width = 10 } }

      it "pads 'select' to 10 characters" do
        expect(described_class.keyword_padding("select")).to eq("select    ")
      end

      it "pads 'from' to 10 characters" do
        expect(described_class.keyword_padding("from")).to eq("from      ")
      end
    end

    context "with :keyword_case set to :upper" do
      before { SqlBeautifier.configure { |config| config.keyword_case = :upper } }

      it "uppercases the keyword" do
        expect(described_class.keyword_padding("select")).to eq("SELECT  ")
      end
    end
  end

  ############################################################################
  ## .continuation_padding
  ############################################################################

  describe ".continuation_padding" do
    it "returns spaces equal to :keyword_column_width" do
      expect(described_class.continuation_padding).to eq("        ")
    end

    context "with custom :keyword_column_width" do
      before { SqlBeautifier.configure { |config| config.keyword_column_width = 10 } }

      it "returns spaces equal to the custom width" do
        expect(described_class.continuation_padding).to eq("          ")
      end
    end
  end

  ############################################################################
  ## .format_keyword
  ############################################################################

  describe ".format_keyword" do
    context "with :lower keyword_case" do
      it "lowercases the keyword" do
        expect(described_class.format_keyword("SELECT")).to eq("select")
      end
    end

    context "with :upper keyword_case" do
      before { SqlBeautifier.configure { |config| config.keyword_case = :upper } }

      it "uppercases the keyword" do
        expect(described_class.format_keyword("select")).to eq("SELECT")
      end
    end
  end

  ############################################################################
  ## .format_table_name
  ############################################################################

  describe ".format_table_name" do
    context "with :pascal_case table_name_format" do
      it "PascalCases underscore-separated names" do
        expect(described_class.format_table_name("user_sessions")).to eq("User_Sessions")
      end

      it "capitalizes single-word names" do
        expect(described_class.format_table_name("users")).to eq("Users")
      end
    end

    context "with :lowercase table_name_format" do
      before { SqlBeautifier.configure { |config| config.table_name_format = :lowercase } }

      it "lowercases the table name" do
        expect(described_class.format_table_name("Users")).to eq("users")
      end

      it "lowercases underscore-separated names" do
        expect(described_class.format_table_name("User_Sessions")).to eq("user_sessions")
      end
    end
  end
end
