# frozen_string_literal: true

RSpec.describe SqlBeautifier::ConditionFormatter do
  describe ".format" do
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
        expect(output).to eq("active = true")
      end
    end

    context "with AND conditions" do
      let(:value) { "active = true and name = 'Alice'" }

      it "formats each condition on its own indented line" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}active = true
          #{' ' * 8}and name = 'Alice'
        SQL
      end
    end

    context "with three AND conditions" do
      let(:value) { "a = 1 and b = 2 and c = 3" }

      it "formats each condition on its own indented line" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and b = 2
          #{' ' * 8}and c = 3
        SQL
      end
    end

    context "with OR-only conditions" do
      let(:value) { "a = 1 or b = 2 or c = 3" }

      it "formats each condition with its OR conjunction" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}or b = 2
          #{' ' * 8}or c = 3
        SQL
      end
    end

    context "with mixed AND/OR conditions" do
      let(:value) { "a = 1 and b = 2 or c = 3" }

      it "formats each condition with its conjunction" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and b = 2
          #{' ' * 8}or c = 3
        SQL
      end
    end

    context "with a short parenthesized group" do
      let(:value) { "active = true and (role = 'admin' or role = 'mod')" }

      it "expands the group to multiple lines" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}active = true
          #{' ' * 8}and (
          #{' ' * 12}role = 'admin'
          #{' ' * 12}or role = 'mod'
          #{' ' * 8})
        SQL
      end
    end

    context "with a long parenthesized group exceeding the inline threshold" do
      let(:value) { "active = true and (very_long_column_name_alpha = 'some_really_long_string_value_here' or very_long_column_name_beta = 'another_really_long_string_value')" }

      it "expands the group to multiple lines with increased indent" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}active = true
          #{' ' * 8}and (
          #{' ' * 12}very_long_column_name_alpha = 'some_really_long_string_value_here'
          #{' ' * 12}or very_long_column_name_beta = 'another_really_long_string_value'
          #{' ' * 8})
        SQL
      end
    end

    context "with same-conjunction groups that can be flattened" do
      let(:value) { "(a = 1 and b = 2) and (c = 3 and d = 4)" }

      it "flattens all inner conditions to the top level" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and b = 2
          #{' ' * 8}and c = 3
          #{' ' * 8}and d = 4
        SQL
      end
    end

    context "with different inner and outer conjunctions preventing flattening" do
      let(:value) { "(a = 1 or b = 2) and (c = 3 or d = 4)" }

      it "expands each group to multiple lines without flattening" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}(
          #{' ' * 12}a = 1
          #{' ' * 12}or b = 2
          #{' ' * 8})
          #{' ' * 8}and (
          #{' ' * 12}c = 3
          #{' ' * 12}or d = 4
          #{' ' * 8})
        SQL
      end
    end

    context "with a redundant outer paren around a single condition" do
      let(:value) { "a = 1 and (b = 2)" }

      it "unwraps the redundant parens" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and b = 2
        SQL
      end
    end

    context "with a single wrapped group as the only condition" do
      let(:value) { "(a = 1 and b = 2)" }

      it "expands the group to multiple lines" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}(
          #{' ' * 12}a = 1
          #{' ' * 12}and b = 2
          #{' ' * 8})
        SQL
      end
    end

    context "with a function call in a condition" do
      let(:value) { "lower(name) = 'alice' and coalesce(status, 'unknown') = 'active'" }

      it "preserves function parentheses" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}lower(name) = 'alice'
          #{' ' * 8}and coalesce(status, 'unknown') = 'active'
        SQL
      end
    end

    context "with a nested parenthesized group inside another group" do
      let(:value) { "a = 1 and (b = 2 or (c = 3 and d = 4))" }

      it "expands each level of nesting to multiple lines" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and (
          #{' ' * 12}b = 2
          #{' ' * 12}or (
          #{' ' * 16}c = 3
          #{' ' * 16}and d = 4
          #{' ' * 12})
          #{' ' * 8})
        SQL
      end
    end

    context "with a custom indent value" do
      let(:value) { "a = 1 and b = 2" }
      let(:output) { described_class.format(value, indent_width: 12) }

      it "uses the specified indentation" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 12}a = 1
          #{' ' * 12}and b = 2
        SQL
      end
    end

    context "with multiple parenthesized groups" do
      let(:value) { "(a = 1 or b = 2) and c = 3 and (d = 4 or e = 5)" }

      it "expands each group to multiple lines alongside plain conditions" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}(
          #{' ' * 12}a = 1
          #{' ' * 12}or b = 2
          #{' ' * 8})
          #{' ' * 8}and c = 3
          #{' ' * 8}and (
          #{' ' * 12}d = 4
          #{' ' * 12}or e = 5
          #{' ' * 8})
        SQL
      end
    end

    context "with same-conjunction OR groups that can be flattened" do
      let(:value) { "(a = 1 or b = 2) or (c = 3 or d = 4)" }

      it "flattens all inner conditions to the top level" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}or b = 2
          #{' ' * 8}or c = 3
          #{' ' * 8}or d = 4
        SQL
      end
    end

    context "with doubly-wrapped redundant parens around a single condition" do
      let(:value) { "a = 1 and ((b = 2))" }

      it "unwraps all redundant layers" do
        expect(output).to eq(<<~SQL.chomp)
          #{' ' * 8}a = 1
          #{' ' * 8}and b = 2
        SQL
      end
    end
  end
end
