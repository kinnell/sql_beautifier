# frozen_string_literal: true

RSpec.describe SqlBeautifier::CteQuery do
  describe ".parse" do
    context "with a non-CTE query" do
      let(:cte_query) { described_class.parse("select * from users") }

      it "returns nil" do
        expect(cte_query).to be_nil
      end
    end

    context "with an identifier starting with 'with'" do
      let(:cte_query) { described_class.parse("withdraw_funds(100)") }

      it "returns nil" do
        expect(cte_query).to be_nil
      end
    end

    context "with an incomplete WITH statement" do
      let(:cte_query) { described_class.parse("with") }

      it "returns nil" do
        expect(cte_query).to be_nil
      end
    end

    context "with a single CTE definition" do
      let(:cte_query) { described_class.parse("with active_users as (select id from users) select * from active_users") }

      it "is not recursive" do
        expect(cte_query.recursive).to be false
      end

      it "returns one definition" do
        expect(cte_query.definitions.length).to eq(1)
      end

      it "parses the CTE name" do
        expect(cte_query.definitions.first.name).to eq("active_users")
      end

      it "parses the CTE body" do
        expect(cte_query.definitions.first.body_sql).to eq("select id from users")
      end

      it "has no column list" do
        expect(cte_query.definitions.first.column_list).to be_nil
      end

      it "parses the main query" do
        expect(cte_query.main_query_sql).to eq("select * from active_users")
      end
    end

    context "with multiple CTE definitions" do
      let(:cte_query) { described_class.parse("with a as (select 1), b as (select 2) select * from a, b") }

      it "is not recursive" do
        expect(cte_query.recursive).to be false
      end

      it "returns two definitions" do
        expect(cte_query.definitions.length).to eq(2)
      end

      it "parses the first CTE name" do
        expect(cte_query.definitions[0].name).to eq("a")
      end

      it "parses the first CTE body" do
        expect(cte_query.definitions[0].body_sql).to eq("select 1")
      end

      it "parses the second CTE name" do
        expect(cte_query.definitions[1].name).to eq("b")
      end

      it "parses the second CTE body" do
        expect(cte_query.definitions[1].body_sql).to eq("select 2")
      end

      it "parses the main query" do
        expect(cte_query.main_query_sql).to eq("select * from a, b")
      end
    end

    context "with a recursive CTE" do
      let(:cte_query) { described_class.parse("with recursive running_total as (select 1 union all select n + 1 from running_total where n < 10) select * from running_total") }

      it "is recursive" do
        expect(cte_query.recursive).to be true
      end

      it "parses the CTE name" do
        expect(cte_query.definitions.first.name).to eq("running_total")
      end

      it "parses the main query" do
        expect(cte_query.main_query_sql).to eq("select * from running_total")
      end
    end

    context "with a CTE column list" do
      let(:cte_query) { described_class.parse("with active_users(a, b) as (select 1, 2) select * from active_users") }

      it "parses the CTE name" do
        expect(cte_query.definitions.first.name).to eq("active_users")
      end

      it "parses the column list" do
        expect(cte_query.definitions.first.column_list).to eq("a, b")
      end

      it "parses the CTE body" do
        expect(cte_query.definitions.first.body_sql).to eq("select 1, 2")
      end

      it "parses the main query" do
        expect(cte_query.main_query_sql).to eq("select * from active_users")
      end
    end

    context "with a materialized CTE" do
      let(:cte_query) { described_class.parse("with active_users as materialized (select 1) select * from active_users") }

      it "parses the materialization mode" do
        expect(cte_query.definitions.first.materialization).to eq("materialized")
      end

      it "parses the CTE body" do
        expect(cte_query.definitions.first.body_sql).to eq("select 1")
      end
    end

    context "with a not materialized CTE" do
      let(:cte_query) { described_class.parse("with active_users as not materialized (select 1) select * from active_users") }

      it "parses the materialization mode" do
        expect(cte_query.definitions.first.materialization).to eq("not materialized")
      end

      it "parses the CTE body" do
        expect(cte_query.definitions.first.body_sql).to eq("select 1")
      end
    end

    context "with nested parentheses in the CTE body" do
      let(:cte_query) { described_class.parse("with active_users as (select count(id) from users where active = true) select * from active_users") }

      it "parses the full body including function calls" do
        expect(cte_query.definitions.first.body_sql).to eq("select count(id) from users where active = true")
      end
    end

    context "with string literals containing parentheses in the CTE body" do
      let(:cte_query) { described_class.parse("with active_users as (select id from users where name = 'O''Brien') select * from active_users") }

      it "parses the full body including the string literal" do
        expect(cte_query.definitions.first.body_sql).to eq("select id from users where name = 'O''Brien'")
      end
    end

    context "with a quoted CTE identifier" do
      let(:cte_query) { described_class.parse("with \"my cte\" as (select id from users) select * from \"my cte\"") }

      it "parses the quoted CTE name" do
        expect(cte_query.definitions.first.name).to eq("\"my cte\"")
      end

      it "parses the main query" do
        expect(cte_query.main_query_sql).to eq("select * from \"my cte\"")
      end
    end

    context "without CTE definition syntax" do
      let(:cte_query) { described_class.parse("select * from users") }

      it "returns nil" do
        expect(cte_query).to be_nil
      end
    end
  end

  describe "#render" do
    context "with a single CTE" do
      let(:output) { described_class.parse("with active_users as (select id, name from users where active = true) select * from active_users").render }

      it "starts with the unpadded WITH keyword and definition" do
        expect(output).to start_with("with Active_Users as (")
      end

      it "indents the CTE body by one indent level" do
        expect(output).to include("    select  id,")
        expect(output).to include("            name")
      end

      it "places the closing paren at column zero" do
        expect(output).to include("\n)\n")
      end

      it "separates the CTE from the main query with a blank line" do
        expect(output).to include_formatted_text(<<~SQL.chomp)
          )

          select
        SQL
      end

      it "formats the main query" do
        expect(output).to include(<<~SQL.chomp)
          select  *
          from    Active_Users au
        SQL
      end
    end

    context "with multiple CTEs" do
      let(:output) { described_class.parse("with a as (select id from users), b as (select user_id, total from orders) select * from a, b").render }

      it "separates CTEs with a comma and newline" do
        expect(output).to include_formatted_text(<<~SQL.chomp)
          ),
          B as (
        SQL
      end

      it "starts subsequent CTE names at column zero" do
        second_cte_line = output.lines.find { |line| line.include?("B as (") }

        expect(second_cte_line).to start_with("B as (")
      end
    end

    context "with a recursive CTE" do
      let(:output) { described_class.parse("with recursive numbers as (select 1 as n) select * from numbers").render }

      it "includes the recursive keyword after WITH" do
        expect(output).to start_with("with recursive Numbers as (")
      end
    end

    context "with a CTE column list" do
      let(:output) { described_class.parse("with active_users (a, b) as (select 1, 2) select * from active_users").render }

      it "preserves the column list in the header" do
        expect(output).to start_with("with Active_Users (a, b) as (")
      end
    end

    context "with a materialized CTE" do
      let(:output) { described_class.parse("with active_users as materialized (select id from users) select * from active_users").render }

      it "keeps the materialized keyword in the CTE header" do
        expect(output).to start_with("with Active_Users as materialized (")
      end
    end

    context "with a not materialized CTE" do
      let(:output) { described_class.parse("with active_users as not materialized (select id from users) select * from active_users").render }

      it "keeps the not materialized keywords in the CTE header" do
        expect(output).to start_with("with Active_Users as not materialized (")
      end
    end

    context "with a quoted CTE identifier" do
      let(:output) { described_class.parse("with \"my cte\" as (select id from users) select * from \"my cte\"").render }

      it "formats the CTE header" do
        expect(output).to start_with("with \"my cte\" as (")
      end
    end

    context "with a non-zero depth" do
      let(:sql) { "with a as (select id from users), b as (select user_id from orders) select * from a, b" }
      let(:depth_zero_output) { described_class.parse(sql, depth: 0).render }
      let(:depth_sixteen_output) { described_class.parse(sql, depth: 16).render }

      it "does not inflate CTE indentation based on depth" do
        expect(depth_sixteen_output).to eq(depth_zero_output)
      end
    end
  end
end
