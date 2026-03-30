# frozen_string_literal: true

RSpec.describe SqlBeautifier::Condition, ".format" do
  let(:output) { described_class.format(value, indent_width: 8) }

  context "with an empty string" do
    let(:value) { "" }

    it "returns the empty string" do
      expect(output).to eq("")
    end
  end

  context "with a whitespace-only string" do
    let(:value) { "   " }

    it "returns an empty string" do
      expect(output).to eq("")
    end
  end

  context "with a single condition" do
    let(:value) { "active = true" }

    it "returns the condition as-is" do
      expect(output).to match_formatted_text(<<~SQL)
        active = true
      SQL
    end
  end

  context "with AND conditions" do
    let(:value) { "active = true and name = 'Alice'" }

    it "formats each condition on its own indented line" do
      expect(output).to match_formatted_text(<<~SQL)
        ········active = true
        ········and name = 'Alice'
      SQL
    end
  end

  context "with three AND conditions" do
    let(:value) { "a = 1 and b = 2 and c = 3" }

    it "formats each condition on its own indented line" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and b = 2
        ········and c = 3
      SQL
    end
  end

  context "with OR-only conditions" do
    let(:value) { "a = 1 or b = 2 or c = 3" }

    it "formats each condition with its OR conjunction" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········or b = 2
        ········or c = 3
      SQL
    end
  end

  context "with mixed AND/OR conditions" do
    let(:value) { "a = 1 and b = 2 or c = 3" }

    it "formats each condition with its conjunction" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and b = 2
        ········or c = 3
      SQL
    end
  end

  context "with a short parenthesized group" do
    let(:value) { "active = true and (role = 'admin' or role = 'mod')" }

    it "expands the group to multiple lines" do
      expect(output).to match_formatted_text(<<~SQL)
        ········active = true
        ········and (
        ············role = 'admin'
        ············or role = 'mod'
        ········)
      SQL
    end
  end

  context "with a long parenthesized group exceeding the inline threshold" do
    let(:value) { "active = true and (very_long_column_name_alpha = 'some_really_long_string_value_here' or very_long_column_name_beta = 'another_really_long_string_value')" }

    it "expands the group to multiple lines with increased indent" do
      expect(output).to match_formatted_text(<<~SQL)
        ········active = true
        ········and (
        ············very_long_column_name_alpha = 'some_really_long_string_value_here'
        ············or very_long_column_name_beta = 'another_really_long_string_value'
        ········)
      SQL
    end
  end

  context "with same-conjunction groups that can be flattened" do
    let(:value) { "(a = 1 and b = 2) and (c = 3 and d = 4)" }

    it "flattens all inner conditions to the top level" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and b = 2
        ········and c = 3
        ········and d = 4
      SQL
    end
  end

  context "with different inner and outer conjunctions preventing flattening" do
    let(:value) { "(a = 1 or b = 2) and (c = 3 or d = 4)" }

    it "expands each group to multiple lines without flattening" do
      expect(output).to match_formatted_text(<<~SQL)
        ········(
        ············a = 1
        ············or b = 2
        ········)
        ········and (
        ············c = 3
        ············or d = 4
        ········)
      SQL
    end
  end

  context "with a redundant outer paren around a single condition" do
    let(:value) { "a = 1 and (b = 2)" }

    it "unwraps the redundant parens" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and b = 2
      SQL
    end
  end

  context "with a single wrapped group as the only condition" do
    let(:value) { "(a = 1 and b = 2)" }

    it "expands the group to multiple lines" do
      expect(output).to match_formatted_text(<<~SQL)
        ········(
        ············a = 1
        ············and b = 2
        ········)
      SQL
    end
  end

  context "with a function call in a condition" do
    let(:value) { "lower(name) = 'alice' and coalesce(status, 'unknown') = 'active'" }

    it "preserves function parentheses" do
      expect(output).to match_formatted_text(<<~SQL)
        ········lower(name) = 'alice'
        ········and coalesce(status, 'unknown') = 'active'
      SQL
    end
  end

  context "with a nested parenthesized group inside another group" do
    let(:value) { "a = 1 and (b = 2 or (c = 3 and d = 4))" }

    it "expands each level of nesting to multiple lines" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and (
        ············b = 2
        ············or (
        ················c = 3
        ················and d = 4
        ············)
        ········)
      SQL
    end
  end

  context "with a custom indent value" do
    let(:value) { "a = 1 and b = 2" }
    let(:output) { described_class.format(value, indent_width: 12) }

    it "uses the specified indentation" do
      expect(output).to match_formatted_text(<<~SQL)
        ············a = 1
        ············and b = 2
      SQL
    end
  end

  context "with multiple parenthesized groups" do
    let(:value) { "(a = 1 or b = 2) and c = 3 and (d = 4 or e = 5)" }

    it "expands each group to multiple lines alongside plain conditions" do
      expect(output).to match_formatted_text(<<~SQL)
        ········(
        ············a = 1
        ············or b = 2
        ········)
        ········and c = 3
        ········and (
        ············d = 4
        ············or e = 5
        ········)
      SQL
    end
  end

  context "with same-conjunction OR groups that can be flattened" do
    let(:value) { "(a = 1 or b = 2) or (c = 3 or d = 4)" }

    it "flattens all inner conditions to the top level" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········or b = 2
        ········or c = 3
        ········or d = 4
      SQL
    end
  end

  context "with doubly-wrapped redundant parens around a single condition" do
    let(:value) { "a = 1 and ((b = 2))" }

    it "unwraps all redundant layers" do
      expect(output).to match_formatted_text(<<~SQL)
        ········a = 1
        ········and b = 2
      SQL
    end
  end
end
