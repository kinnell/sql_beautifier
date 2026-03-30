# frozen_string_literal: true

RSpec.describe SqlBeautifier::CaseExpression do
  ############################################################################
  ## .parse
  ############################################################################

  describe ".parse" do
    context "with a searched CASE with two WHEN/THEN pairs and ELSE" do
      let(:parsed) { described_class.parse("case when x = 1 then 'one' when x = 2 then 'two' else 'other' end") }

      it "parses the first WHEN condition" do
        expect(parsed.when_clauses[0][:condition]).to eq("x = 1")
      end

      it "parses the first THEN result" do
        expect(parsed.when_clauses[0][:result]).to eq("'one'")
      end

      it "parses the second WHEN condition" do
        expect(parsed.when_clauses[1][:condition]).to eq("x = 2")
      end

      it "parses the second THEN result" do
        expect(parsed.when_clauses[1][:result]).to eq("'two'")
      end

      it "parses the ELSE value" do
        expect(parsed.else_value).to eq("'other'")
      end

      it "has no operand" do
        expect(parsed.operand).to be_nil
      end
    end

    context "with a simple CASE with operand" do
      let(:parsed) { described_class.parse("case x when 1 then 'one' when 2 then 'two' end") }

      it "extracts the operand" do
        expect(parsed.operand).to eq("x")
      end

      it "parses the first WHEN condition" do
        expect(parsed.when_clauses[0][:condition]).to eq("1")
      end

      it "parses the first THEN result" do
        expect(parsed.when_clauses[0][:result]).to eq("'one'")
      end

      it "parses the second WHEN condition" do
        expect(parsed.when_clauses[1][:condition]).to eq("2")
      end

      it "has no ELSE value" do
        expect(parsed.else_value).to be_nil
      end
    end

    context "with a CASE without ELSE" do
      let(:parsed) { described_class.parse("case when x > 0 then 'positive' end") }

      it "parses the WHEN clause" do
        expect(parsed.when_clauses.length).to eq(1)
      end

      it "has no ELSE value" do
        expect(parsed.else_value).to be_nil
      end
    end

    context "with a nested CASE inside a THEN value" do
      let(:parsed) { described_class.parse("case when x = 1 then case when y = 1 then 'a' else 'b' end when x = 2 then 'c' end") }

      it "parses both outer WHEN clauses" do
        expect(parsed.when_clauses.length).to eq(2)
      end

      it "captures the inner CASE as the first THEN result" do
        expect(parsed.when_clauses[0][:result]).to eq("case when y = 1 then 'a' else 'b' end")
      end

      it "parses the second THEN result" do
        expect(parsed.when_clauses[1][:result]).to eq("'c'")
      end
    end

    context "with string literals containing SQL keywords" do
      let(:parsed) { described_class.parse("case when x = 'when' then 'then end' else 'case' end") }

      it "parses the WHEN condition correctly" do
        expect(parsed.when_clauses[0][:condition]).to eq("x = 'when'")
      end

      it "parses the THEN result correctly" do
        expect(parsed.when_clauses[0][:result]).to eq("'then end'")
      end

      it "parses the ELSE value correctly" do
        expect(parsed.else_value).to eq("'case'")
      end
    end

    context "with non-CASE text" do
      let(:parsed) { described_class.parse("select id from users") }

      it "returns nil" do
        expect(parsed).to be_nil
      end
    end

    context "with a CASE with no END" do
      let(:parsed) { described_class.parse("case when x = 1 then 'one'") }

      it "returns nil" do
        expect(parsed).to be_nil
      end
    end

    context "with a CASE with numeric THEN and ELSE values" do
      let(:parsed) { described_class.parse("case when x > 0 then x else 0 end") }

      it "parses the WHEN condition" do
        expect(parsed.when_clauses[0][:condition]).to eq("x > 0")
      end

      it "parses the THEN result" do
        expect(parsed.when_clauses[0][:result]).to eq("x")
      end

      it "parses the ELSE value" do
        expect(parsed.else_value).to eq("0")
      end
    end

    context "with a simple CASE with a dotted operand" do
      let(:parsed) { described_class.parse("case u.role when 'admin' then 1 when 'user' then 2 end") }

      it "extracts the dotted operand" do
        expect(parsed.operand).to eq("u.role")
      end

      it "parses the WHEN conditions" do
        expect(parsed.when_clauses[0][:condition]).to eq("'admin'")
        expect(parsed.when_clauses[1][:condition]).to eq("'user'")
      end
    end
  end

  ############################################################################
  ## #render
  ############################################################################

  describe "#render" do
    before do
      SqlBeautifier.configure do |config|
        config.inline_group_threshold = threshold
      end
    end

    context "when the CASE expression is below the inline threshold" do
      let(:threshold) { 200 }
      let(:expression) do
        described_class.new(
          when_clauses: [
            { condition: "x = 1", result: "'one'" },
          ],
          else_value: "'other'"
        )
      end

      it "renders inline" do
        expect(expression.render).to eq("case when x = 1 then 'one' else 'other' end")
      end
    end

    context "when the CASE expression exceeds the inline threshold" do
      let(:threshold) { 10 }
      let(:expression) do
        described_class.new(
          when_clauses: [
            { condition: "u.status = 'active'", result: "'Active'" },
            { condition: "u.status = 'pending'", result: "'Pending'" },
          ],
          else_value: "'Unknown'"
        )
      end

      it "renders expanded with indentation" do
        expect(expression.render).to eq(<<~SQL.chomp)
          case
              when u.status = 'active' then 'Active'
              when u.status = 'pending' then 'Pending'
              else 'Unknown'
          end
        SQL
      end
    end

    context "when the CASE has an operand (simple CASE)" do
      let(:threshold) { 10 }
      let(:expression) do
        described_class.new(
          operand: "u.role",
          when_clauses: [
            { condition: "'admin'", result: "'Administrator'" },
            { condition: "'user'", result: "'Standard User'" },
          ],
          else_value: "'Guest'"
        )
      end

      it "renders the operand on the CASE line" do
        expect(expression.render).to eq(<<~SQL.chomp)
          case u.role
              when 'admin' then 'Administrator'
              when 'user' then 'Standard User'
              else 'Guest'
          end
        SQL
      end
    end

    context "when the CASE has a base_indent" do
      let(:threshold) { 10 }
      let(:expression) do
        described_class.new(
          when_clauses: [
            { condition: "x = 1", result: "'one'" },
            { condition: "x = 2", result: "'two'" },
          ],
          base_indent: 8
        )
      end

      it "indents inner lines relative to base_indent" do
        expected = [
          "case",
          "            when x = 1 then 'one'",
          "            when x = 2 then 'two'",
          "        end",
        ].join("\n")

        expect(expression.render).to eq(expected)
      end
    end

    context "when the CASE has no ELSE" do
      let(:threshold) { 10 }
      let(:expression) do
        described_class.new(
          when_clauses: [
            { condition: "x > 0", result: "'positive'" },
          ]
        )
      end

      it "renders without an ELSE line" do
        expect(expression.render).to eq(<<~SQL.chomp)
          case
              when x > 0 then 'positive'
          end
        SQL
      end
    end

    context "when the inline threshold is 0 (default)" do
      let(:threshold) { 0 }
      let(:expression) do
        described_class.new(
          when_clauses: [
            { condition: "x = 1", result: "'a'" },
          ]
        )
      end

      it "always renders expanded" do
        expect(expression.render).to eq(<<~SQL.chomp)
          case
              when x = 1 then 'a'
          end
        SQL
      end
    end
  end

  ############################################################################
  ## .format_in_text
  ############################################################################

  describe ".format_in_text" do
    before do
      SqlBeautifier.configure do |config|
        config.inline_group_threshold = 0
      end
    end

    context "with text containing a single CASE block" do
      let(:text) { "case when x = 1 then 'one' else 'other' end" }
      let(:output) { described_class.format_in_text(text) }

      it "formats the CASE block in place" do
        expect(output).to eq(<<~SQL.chomp)
          case
              when x = 1 then 'one'
              else 'other'
          end
        SQL
      end
    end

    context "with text containing no CASE block" do
      let(:text) { "u.id" }
      let(:output) { described_class.format_in_text(text) }

      it "returns the text unchanged" do
        expect(output).to eq("u.id")
      end
    end

    context "with a CASE inside a function call" do
      let(:text) { "coalesce(case when x > 0 then x else 0 end, 0)" }
      let(:output) { described_class.format_in_text(text) }

      it "does not format the CASE inside parentheses" do
        expect(output).to eq("coalesce(case when x > 0 then x else 0 end, 0)")
      end
    end

    context "with multiple CASE blocks in the text" do
      let(:text) { "case when a = 1 then 'x' end, case when b = 2 then 'y' end" }
      let(:output) { described_class.format_in_text(text) }

      it "formats both CASE blocks" do
        expect(output).to include("case\n    when a = 1 then 'x'\nend")
        expect(output).to include("case\n    when b = 2 then 'y'\nend")
      end
    end

    context "with a CASE keyword inside a string literal" do
      let(:text) { "'case when then end'" }
      let(:output) { described_class.format_in_text(text) }

      it "does not modify string contents" do
        expect(output).to eq("'case when then end'")
      end
    end

    context "with a case_-prefixed identifier" do
      let(:text) { "case_id = 1" }
      let(:output) { described_class.format_in_text(text) }

      it "does not treat case_id as a CASE keyword" do
        expect(output).to eq("case_id = 1")
      end
    end

    context "with an end_-prefixed identifier" do
      let(:text) { "case when end_date > now() then 'future' else 'past' end" }
      let(:output) { described_class.format_in_text(text) }

      it "does not treat end_date as an END keyword" do
        expect(output).to eq(<<~SQL.chomp)
          case
              when end_date > now() then 'future'
              else 'past'
          end
        SQL
      end
    end
  end
end
