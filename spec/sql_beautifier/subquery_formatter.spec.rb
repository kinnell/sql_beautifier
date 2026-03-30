# frozen_string_literal: true

RSpec.describe SqlBeautifier::Query, "subquery formatting" do
  describe ".format_subqueries_in_text" do
    let(:output) { described_class.format_subqueries_in_text(text, depth: depth) }
    let(:depth) { 0 }

    context "with no subqueries" do
      let(:text) do
        <<~SQL.chomp
          select  id

          from    Users u
        SQL
      end

      it "passes text through unchanged" do
        expect(output).to eq(text)
      end
    end

    context "with a simple subquery" do
      let(:text) { "where   id in (select user_id from orders)" }

      it "preserves the outer clause" do
        expect(output).to include("where   id in (")
      end

      it "indents the subquery select" do
        expect(output).to include("          select  user_id")
      end

      it "indents the subquery from" do
        expect(output).to include("          from    Orders o")
      end

      it "closes the subquery with indentation" do
        expect(output).to include("        )")
      end
    end

    context "with a subquery at non-zero depth" do
      let(:text) { "where   id in (select user_id from orders)" }
      let(:depth) { 4 }

      it "indents the subquery content relative to keyword column width" do
        expect(output).to include("            select  user_id")
      end

      it "indents the closing paren at keyword column width" do
        expect(output).to include("        )")
      end
    end

    context "with :indent_spaces configured" do
      let(:text) { "where   id in (select user_id from orders)" }

      before do
        SqlBeautifier.configure do |config|
          config.indent_spaces = 6
        end
      end

      it "uses the configured indentation width for subquery content" do
        expect(output).to include("              select  user_id")
      end
    end

    context "with uppercase where text" do
      let(:text) { "WHERE   id in (select user_id from orders)" }

      before do
        SqlBeautifier.configure do |config|
          config.keyword_case = :upper
        end
      end

      it "applies where-specific base indentation case-insensitively" do
        expect(output).to include("          SELECT  user_id")
      end
    end

    context "with multiple subqueries" do
      let(:text) { "where   id in (select user_id from orders) and status in (select code from statuses)" }

      it "formats the first subquery" do
        expect(output).to include("id in (")
      end

      it "formats the second subquery" do
        expect(output).to include("status in (")
      end

      it "formats both select keywords" do
        expect(output.scan("select  ").length).to eq(2)
      end
    end

    context "with a subquery nested inside additional parentheses" do
      let(:text) { "where   (id in (select user_id from orders))" }

      it "preserves the outer parentheses" do
        expect(output).to include("where   (id in (")
      end

      it "indents the nested subquery select" do
        expect(output).to include("            select  user_id")
      end

      it "indents the nested subquery from" do
        expect(output).to include("            from    Orders o")
      end
    end

    context "with select text inside a double-quoted identifier" do
      let(:text) { 'where   note = "(select bad)" and id in (select user_id from orders)' }

      it "does not treat the identifier text as a subquery" do
        expect(output).to include('where   note = "(select bad)" and id in (')
      end

      it "formats the real subquery" do
        expect(output).to include("          select  user_id")
      end
    end
  end

  describe ".format_as_subquery" do
    context "with a simple query" do
      let(:output) { described_class.format_as_subquery("select user_id from orders", base_indent: 8) }

      it "starts with an opening paren" do
        expect(output).to start_with("(")
      end

      it "ends with a closing paren" do
        expect(output).to end_with(")")
      end

      it "indents the subquery select" do
        expect(output).to include("          select  user_id")
      end

      it "indents the closing paren" do
        expect(output).to include("        )")
      end
    end

    context "with base_indent of 0" do
      let(:output) { described_class.format_as_subquery("select 1", base_indent: 0) }

      it "indents from column 0" do
        expect(output).to include("  select  1")
      end

      it "ends with a closing paren" do
        expect(output).to end_with(")")
      end
    end
  end
end
