# frozen_string_literal: true

RSpec.describe SqlBeautifier::CteFormatter do
  describe ".cte_query?" do
    subject(:cte_query) { described_class.cte_query?(sql) }

    context "with a WITH query" do
      let(:sql) { "with cte as (select 1) select * from cte" }

      it "returns true" do
        expect(cte_query).to be true
      end
    end

    context "with a WITH RECURSIVE query" do
      let(:sql) { "with recursive cte as (select 1) select * from cte" }

      it "returns true" do
        expect(cte_query).to be true
      end
    end

    context "with a SELECT query" do
      let(:sql) { "select * from users" }

      it "returns false" do
        expect(cte_query).to be false
      end
    end

    context "with an identifier starting with 'with'" do
      let(:sql) { "withdraw_funds(100)" }

      it "returns false" do
        expect(cte_query).to be false
      end
    end
  end

  describe ".parse" do
    subject(:result) { described_class.parse(sql) }

    let(:recursive) { result[0] }
    let(:definitions) { result[1] }
    let(:main_query) { result[2] }

    context "with a single CTE definition" do
      let(:sql) { "with cte as (select id from users) select * from cte" }

      it "is not recursive" do
        expect(recursive).to be false
      end

      it "returns one definition" do
        expect(definitions.length).to eq(1)
      end

      it "parses the CTE name" do
        expect(definitions.first[:name]).to eq("cte")
      end

      it "parses the CTE body" do
        expect(definitions.first[:body]).to eq("select id from users")
      end

      it "has no column list" do
        expect(definitions.first[:column_list]).to be_nil
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with multiple CTE definitions" do
      let(:sql) { "with a as (select 1), b as (select 2) select * from a, b" }

      it "is not recursive" do
        expect(recursive).to be false
      end

      it "returns two definitions" do
        expect(definitions.length).to eq(2)
      end

      it "parses the first CTE name" do
        expect(definitions[0][:name]).to eq("a")
      end

      it "parses the first CTE body" do
        expect(definitions[0][:body]).to eq("select 1")
      end

      it "parses the second CTE name" do
        expect(definitions[1][:name]).to eq("b")
      end

      it "parses the second CTE body" do
        expect(definitions[1][:body]).to eq("select 2")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from a, b")
      end
    end

    context "with a recursive CTE" do
      let(:sql) { "with recursive cte as (select 1 union all select n + 1 from cte where n < 10) select * from cte" }

      it "is recursive" do
        expect(recursive).to be true
      end

      it "parses the CTE name" do
        expect(definitions.first[:name]).to eq("cte")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with a CTE column list" do
      let(:sql) { "with cte(a, b) as (select 1, 2) select * from cte" }

      it "parses the CTE name" do
        expect(definitions.first[:name]).to eq("cte")
      end

      it "parses the column list" do
        expect(definitions.first[:column_list]).to eq("a, b")
      end

      it "parses the CTE body" do
        expect(definitions.first[:body]).to eq("select 1, 2")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with a materialized CTE" do
      let(:sql) { "with cte as materialized (select 1) select * from cte" }

      it "parses the CTE name" do
        expect(definitions.first[:name]).to eq("cte")
      end

      it "parses the :materialization mode" do
        expect(definitions.first[:materialization]).to eq("materialized")
      end

      it "parses the CTE body" do
        expect(definitions.first[:body]).to eq("select 1")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with a not materialized CTE" do
      let(:sql) { "with cte as not materialized (select 1) select * from cte" }

      it "parses the CTE name" do
        expect(definitions.first[:name]).to eq("cte")
      end

      it "parses the :materialization mode" do
        expect(definitions.first[:materialization]).to eq("not materialized")
      end

      it "parses the CTE body" do
        expect(definitions.first[:body]).to eq("select 1")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with nested parentheses in the CTE body" do
      let(:sql) { "with cte as (select count(id) from users where active = true) select * from cte" }

      it "parses the full body including function calls" do
        expect(definitions.first[:body]).to eq("select count(id) from users where active = true")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with string literals containing parentheses in the CTE body" do
      let(:sql) { "with cte as (select id from users where name = 'O''Brien') select * from cte" }

      it "parses the full body including the string literal" do
        expect(definitions.first[:body]).to eq("select id from users where name = 'O''Brien'")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from cte")
      end
    end

    context "with a quoted CTE identifier" do
      let(:sql) { "with \"my cte\" as (select id from users) select * from \"my cte\"" }

      it "parses the quoted CTE name" do
        expect(definitions.first[:name]).to eq("\"my cte\"")
      end

      it "parses the main query" do
        expect(main_query).to eq("select * from \"my cte\"")
      end
    end
  end

  describe ".parse_definition" do
    subject(:result) { described_class.parse_definition(sql, 0) }

    let(:definition) { result&.first }

    context "without CTE definition syntax" do
      let(:sql) { "select * from users" }

      it "returns nil" do
        expect(definition).to be_nil
      end
    end

    context "without the AS keyword" do
      let(:sql) { "cte (select 1)" }

      it "returns nil" do
        expect(definition).to be_nil
      end
    end

    context "without a closing parenthesis" do
      let(:sql) { "cte as (select 1" }

      it "returns nil" do
        expect(definition).to be_nil
      end
    end
  end

  describe ".format" do
    subject(:output) { described_class.format(sql) }

    context "with a non-CTE query" do
      let(:sql) { "select * from users" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an incomplete WITH statement" do
      let(:sql) { "with" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a single CTE" do
      let(:sql) { "with active_users as (select id, name from users where active = true) select * from active_users" }

      it "starts with the padded WITH keyword and definition" do
        expect(output).to start_with("with    active_users as (")
      end

      it "indents the CTE body content" do
        expect(output).to include("            select  id,")
        expect(output).to include("                    name")
      end

      it "places the closing paren at the keyword column" do
        expect(output).to include("        )\n")
      end

      it "separates the CTE from the main query with a blank line" do
        expect(output).to include("        )\n\nselect")
      end

      it "formats the main query" do
        expect(output).to include("select  *\nfrom    Active_Users au")
      end
    end

    context "with multiple CTEs" do
      let(:sql) { "with a as (select id from users), b as (select user_id, total from orders) select * from a, b" }

      it "separates CTEs with a comma and newline" do
        expect(output).to include("),\n        b as (")
      end

      it "aligns subsequent CTE names at the keyword column" do
        second_cte_line = output.lines.find { |line| line.include?("b as (") }

        expect(second_cte_line).to start_with("        b as (")
      end
    end

    context "with a recursive CTE" do
      let(:sql) { "with recursive numbers as (select 1 as n) select * from numbers" }

      it "includes the recursive keyword after the WITH padding" do
        expect(output).to start_with("with    recursive numbers as (")
      end
    end

    context "with a CTE column list" do
      let(:sql) { "with cte (a, b) as (select 1, 2) select * from cte" }

      it "preserves the column list in the header" do
        expect(output).to start_with("with    cte (a, b) as (")
      end
    end

    context "with a materialized CTE" do
      let(:sql) { "with cte as materialized (select id from users) select * from cte" }

      it "keeps the :materialized keyword in the CTE header" do
        expect(output).to start_with("with    cte as materialized (")
      end
    end

    context "with a not materialized CTE" do
      let(:sql) { "with cte as not materialized (select id from users) select * from cte" }

      it "keeps the :not materialized keywords in the CTE header" do
        expect(output).to start_with("with    cte as not materialized (")
      end
    end

    context "with a quoted CTE identifier" do
      let(:sql) { "with \"my cte\" as (select id from users) select * from \"my cte\"" }

      it "formats the CTE header with keyword padding" do
        expect(output).to start_with("with    \"my cte\" as (")
      end
    end

    context "with a non-zero depth" do
      subject(:output) { described_class.format(sql, depth: 16) }

      let(:sql) { "with a as (select id from users), b as (select user_id from orders) select * from a, b" }

      it "does not inflate CTE indentation based on depth" do
        depth_zero_output = described_class.format(sql, depth: 0)

        expect(output).to eq(depth_zero_output)
      end
    end
  end
end
