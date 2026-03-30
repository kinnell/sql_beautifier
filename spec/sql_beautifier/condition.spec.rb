# frozen_string_literal: true

RSpec.describe SqlBeautifier::Condition do
  describe ".parse_all" do
    let(:conditions) { described_class.parse_all(text) }

    context "with a single condition" do
      let(:text) { "active = true" }

      it "returns one leaf condition" do
        expect(conditions.length).to eq(1)
      end

      it "has no conjunction on the first condition" do
        expect(conditions.first.conjunction).to be_nil
      end

      it "stores the expression" do
        expect(conditions.first.expression).to eq("active = true")
      end

      it "is a leaf" do
        expect(conditions.first).to be_leaf
      end
    end

    context "with AND conditions" do
      let(:text) { "a = 1 and b = 2 and c = 3" }

      it "returns three conditions" do
        expect(conditions.length).to eq(3)
      end

      it "has nil conjunction for the first condition" do
        expect(conditions[0].conjunction).to be_nil
      end

      it "has 'and' conjunction for the second condition" do
        expect(conditions[1].conjunction).to eq("and")
      end

      it "has 'and' conjunction for the third condition" do
        expect(conditions[2].conjunction).to eq("and")
      end

      it "stores each expression" do
        expect(conditions.map(&:expression)).to eq(["a = 1", "b = 2", "c = 3"])
      end
    end

    context "with a parenthesized group" do
      let(:text) { "active = true and (role = 'admin' or role = 'mod')" }

      it "returns two conditions" do
        expect(conditions.length).to eq(2)
      end

      it "creates a leaf for the first condition" do
        expect(conditions[0]).to be_leaf
      end

      it "stores the first condition expression" do
        expect(conditions[0].expression).to eq("active = true")
      end

      it "creates a group for the parenthesized condition" do
        expect(conditions[1]).to be_group
      end

      it "stores two children in the group" do
        expect(conditions[1].children.length).to eq(2)
      end

      it "parses the first child expression" do
        expect(conditions[1].children[0].expression).to eq("role = 'admin'")
      end

      it "parses the second child expression" do
        expect(conditions[1].children[1].expression).to eq("role = 'mod'")
      end

      it "sets the conjunction on the second child" do
        expect(conditions[1].children[1].conjunction).to eq("or")
      end
    end

    context "with redundant outer parentheses around a single condition" do
      let(:text) { "a = 1 and (b = 2)" }

      it "unwraps the redundant parens" do
        expect(conditions[1]).to be_leaf
      end

      it "preserves the expression" do
        expect(conditions[1].expression).to eq("b = 2")
      end
    end

    context "with doubly-wrapped redundant parentheses" do
      let(:text) { "a = 1 and ((b = 2))" }

      it "unwraps all layers" do
        expect(conditions[1]).to be_leaf
      end

      it "preserves the expression" do
        expect(conditions[1].expression).to eq("b = 2")
      end
    end

    ############################################################################
    ## NOT prefix paren unwrapping
    ############################################################################

    context "with NOT and doubly-wrapped parentheses around a group" do
      let(:text) { "not ((a = 1 or b = 2)) and c = 3" }

      it "unwraps the redundant outer parens after NOT" do
        expect(conditions[0].expression).to eq("not (a = 1 or b = 2)")
      end

      it "preserves the second condition" do
        expect(conditions[1].expression).to eq("c = 3")
      end
    end

    context "with NOT and single-wrapped parentheses around a single condition" do
      let(:text) { "not (a = 1) and b = 2" }

      it "unwraps the redundant parens after NOT" do
        expect(conditions[0].expression).to eq("not a = 1")
      end
    end

    context "with NOT and triply-wrapped parentheses around a group" do
      let(:text) { "not (((a = 1 or b = 2))) and c = 3" }

      it "unwraps down to a single layer" do
        expect(conditions[0].expression).to eq("not (a = 1 or b = 2)")
      end
    end

    context "with NOT and necessary parentheses around a group" do
      let(:text) { "not (a = 1 or b = 2) and c = 3" }

      it "preserves the necessary parentheses" do
        expect(conditions[0].expression).to eq("not (a = 1 or b = 2)")
      end
    end

    ############################################################################
    ## Flattening
    ############################################################################

    context "with same-conjunction AND groups" do
      let(:text) { "(a = 1 and b = 2) and (c = 3 and d = 4)" }

      it "flattens all inner conditions to the top level" do
        expect(conditions.length).to eq(4)
      end

      it "preserves the expressions in order" do
        expect(conditions.map(&:expression)).to eq(["a = 1", "b = 2", "c = 3", "d = 4"])
      end

      it "assigns correct conjunctions" do
        expect(conditions.map(&:conjunction)).to eq([nil, "and", "and", "and"])
      end
    end

    context "with same-conjunction OR groups" do
      let(:text) { "(a = 1 or b = 2) or (c = 3 or d = 4)" }

      it "flattens all inner conditions to the top level" do
        expect(conditions.length).to eq(4)
      end

      it "preserves the expressions in order" do
        expect(conditions.map(&:expression)).to eq(["a = 1", "b = 2", "c = 3", "d = 4"])
      end

      it "assigns correct conjunctions" do
        expect(conditions.map(&:conjunction)).to eq([nil, "or", "or", "or"])
      end
    end

    context "with different inner and outer conjunctions" do
      let(:text) { "(a = 1 or b = 2) and (c = 3 or d = 4)" }

      it "does not flatten" do
        expect(conditions.length).to eq(2)
      end

      it "preserves both groups" do
        expect(conditions[0]).to be_group
      end

      it "preserves the second group" do
        expect(conditions[1]).to be_group
      end
    end

    context "with a nested group inside a group" do
      let(:text) { "a = 1 and (b = 2 or (c = 3 and d = 4))" }

      it "creates a group for the second condition" do
        expect(conditions[1]).to be_group
      end

      it "nests the inner group as the second child" do
        expect(conditions[1].children[1]).to be_group
      end

      it "parses two children in the inner group" do
        expect(conditions[1].children[1].children.length).to eq(2)
      end
    end
  end

  describe "#leaf?" do
    context "with an expression" do
      let(:condition) { described_class.new(conjunction: nil, expression: "a = 1") }

      it "returns true" do
        expect(condition).to be_leaf
      end
    end

    context "with children" do
      let(:condition) { described_class.new(conjunction: nil, children: [described_class.new(conjunction: nil, expression: "a = 1")]) }

      it "returns false" do
        expect(condition).not_to be_leaf
      end
    end
  end

  describe "#group?" do
    context "with children" do
      let(:condition) { described_class.new(conjunction: nil, children: [described_class.new(conjunction: nil, expression: "a = 1")]) }

      it "returns true" do
        expect(condition).to be_group
      end
    end

    context "with an expression" do
      let(:condition) { described_class.new(conjunction: nil, expression: "a = 1") }

      it "returns false" do
        expect(condition).not_to be_group
      end
    end
  end

  describe "#render" do
    context "with a leaf condition" do
      let(:condition) { described_class.new(conjunction: nil, expression: "active = true") }

      it "returns the expression" do
        expect(condition.render(indent_width: 8)).to eq("active = true")
      end
    end

    context "with a group condition" do
      let(:condition) do
        described_class.new(
          conjunction: "and",
          children: [
            described_class.new(conjunction: nil, expression: "role = 'admin'"),
            described_class.new(conjunction: "or", expression: "role = 'mod'"),
          ]
        )
      end

      it "renders the group with expanded indentation" do
        rendered = condition.render(indent_width: 8)
        expect(rendered).to match_formatted_text(<<~SQL.chomp)
          (
          ············role = 'admin'
          ············or role = 'mod'
          ········)
        SQL
      end
    end

    context "with a nested group and a high inline threshold" do
      let(:condition) do
        described_class.new(
          conjunction: "and",
          children: [
            described_class.new(conjunction: nil, expression: "a = 1"),
            described_class.new(
              conjunction: "or",
              children: [
                described_class.new(conjunction: nil, expression: "b = 2"),
                described_class.new(conjunction: "and", expression: "c = 3"),
              ]
            ),
          ]
        )
      end

      before do
        SqlBeautifier.configure do |config|
          config.inline_group_threshold = 200
        end
      end

      it "renders the nested group inline" do
        expect(condition.render(indent_width: 8)).to eq("(a = 1 or (b = 2 and c = 3))")
      end
    end
  end

  describe ".render_all" do
    let(:output) { described_class.render_all(conditions, indent_width: 8) }

    context "with multiple leaf conditions" do
      let(:conditions) do
        [
          described_class.new(conjunction: nil, expression: "a = 1"),
          described_class.new(conjunction: "and", expression: "b = 2"),
          described_class.new(conjunction: "and", expression: "c = 3"),
        ]
      end

      it "renders each condition on its own indented line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          ········a = 1
          ········and b = 2
          ········and c = 3
        SQL
      end
    end

    context "with a mix of leaf and group conditions" do
      let(:conditions) do
        [
          described_class.new(conjunction: nil, expression: "active = true"),
          described_class.new(
            conjunction: "and",
            children: [
              described_class.new(conjunction: nil, expression: "role = 'admin'"),
              described_class.new(conjunction: "or", expression: "role = 'mod'"),
            ]
          ),
        ]
      end

      it "renders the leaf condition" do
        expect(output).to include_formatted_text("········active = true")
      end

      it "opens the group with a conjunction" do
        expect(output).to include_formatted_text("········and (")
      end

      it "indents the first child" do
        expect(output).to include_formatted_text("············role = 'admin'")
      end

      it "indents the second child with its conjunction" do
        expect(output).to include_formatted_text("············or role = 'mod'")
      end

      it "closes the group at the original indentation" do
        expect(output).to include_formatted_text("········)")
      end
    end
  end

  describe ".format" do
    let(:output) { described_class.format(text, indent_width: 8) }

    context "with AND conditions" do
      let(:text) { "active = true and name = 'Alice'" }

      it "formats via the Condition tree" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          ········active = true
          ········and name = 'Alice'
        SQL
      end
    end

    context "with a single leaf condition" do
      let(:text) { "active = true" }

      it "returns the raw text" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          active = true
        SQL
      end
    end

    context "with a parenthesized group" do
      let(:text) { "active = true and (role = 'admin' or role = 'moderator') and verified = true" }

      it "opens the group" do
        expect(output).to include("and (")
      end

      it "indents the first group child" do
        expect(output).to include("role = 'admin'")
      end

      it "indents the second group child with its conjunction" do
        expect(output).to include("or role = 'moderator'")
      end
    end

    context "with same-conjunction flattening" do
      let(:text) { "(a = 1 and b = 2) and (c = 3 and d = 4)" }

      it "flattens all conditions" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          ········a = 1
          ········and b = 2
          ········and c = 3
          ········and d = 4
        SQL
      end
    end
  end
end
