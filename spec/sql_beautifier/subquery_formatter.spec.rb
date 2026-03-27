# frozen_string_literal: true

RSpec.describe SqlBeautifier::SubqueryFormatter do
  describe ".find_top_level_subquery" do
    subject(:subquery_position) { described_class.find_top_level_subquery(text, start_position) }

    let(:start_position) { 0 }

    context "with a top-level subquery" do
      let(:text) { "id in (select user_id from orders)" }

      it "returns the opening parenthesis position" do
        expect(subquery_position).to eq(6)
      end
    end

    context "with nested parentheses before the subquery" do
      let(:text) { "count(id) in (select user_id from orders)" }

      it "returns the subquery opening parenthesis position" do
        expect(subquery_position).to eq(13)
      end
    end

    context "with a subquery nested inside another parenthesis group" do
      let(:text) { "where (id in (select user_id from orders))" }

      it "returns the nested subquery opening parenthesis position" do
        expect(subquery_position).to eq(13)
      end
    end

    context "with select inside a string literal" do
      let(:text) { "name = '(select bad)' and id in (select 1)" }

      it "ignores the string content and returns the real subquery position" do
        expect(subquery_position).to eq(32)
      end
    end

    context "with select inside a double-quoted identifier" do
      let(:text) { 'name = "(select bad)" and id in (select 1)' }

      it "ignores the identifier content and returns the real subquery position" do
        expect(subquery_position).to eq(32)
      end
    end

    context "without any subquery" do
      let(:text) { "id = 1 and name = 'test'" }

      it "returns nil" do
        expect(subquery_position).to be_nil
      end
    end

    context "with non-select parentheses only" do
      let(:text) { "count(id) + sum(amount)" }

      it "returns nil" do
        expect(subquery_position).to be_nil
      end
    end

    context "with identifiers that start with select" do
      let(:text) { "where result = (selection_score + 1)" }

      it "does not treat the identifier as a subquery" do
        expect(subquery_position).to be_nil
      end
    end
  end

  describe ".format" do
    subject(:output) { described_class.format(text, base_indent) }

    let(:base_indent) { 0 }

    context "with no subqueries" do
      let(:text) { "select  id\n\nfrom    Users u" }

      it "passes text through unchanged" do
        expect(output).to eq(text)
      end
    end

    context "with a simple subquery" do
      let(:text) { "where   id in (select user_id from orders)" }

      it "formats the subquery with indentation" do
        expect(output).to include("where   id in (")
        expect(output).to include("          select  user_id")
        expect(output).to include("          from    Orders o")
        expect(output).to include("        )")
        expect(output).to include(")")
      end
    end

    context "with a subquery at non-zero base indent" do
      let(:text) { "where   id in (select user_id from orders)" }
      let(:base_indent) { 4 }

      it "indents the subquery content relative to the base" do
        expect(output).to include("              select  user_id")
        expect(output).to include("            )")
      end
    end

    context "with :indent_spaces configured" do
      let(:text) { "where   id in (select user_id from orders)" }

      before { SqlBeautifier.configure { |config| config.indent_spaces = 6 } }

      it "uses the configured indentation width for subquery content" do
        expect(output).to include("              select  user_id")
      end
    end

    context "with uppercase where text" do
      let(:text) { "WHERE   id in (select user_id from orders)" }

      before { SqlBeautifier.configure { |config| config.keyword_case = :upper } }

      it "applies where-specific base indentation case-insensitively" do
        expect(output).to include("          SELECT  user_id")
      end
    end

    context "with multiple subqueries" do
      let(:text) { "where   id in (select user_id from orders) and status in (select code from statuses)" }

      it "formats each subquery independently" do
        expect(output).to include("id in (")
        expect(output).to include("status in (")
        expect(output.scan("select  ").length).to eq(2)
      end
    end

    context "with a subquery nested inside additional parentheses" do
      let(:text) { "where   (id in (select user_id from orders))" }

      it "formats the nested subquery" do
        expect(output).to include("where   (id in (")
        expect(output).to include("            select  user_id")
        expect(output).to include("            from    Orders o")
        expect(output).to include("))")
      end
    end

    context "with select text inside a double-quoted identifier" do
      let(:text) { 'where   note = "(select bad)" and id in (select user_id from orders)' }

      it "does not treat the identifier text as a subquery" do
        expect(output).to include('where   note = "(select bad)" and id in (')
        expect(output).to include("          select  user_id")
      end
    end
  end
end
