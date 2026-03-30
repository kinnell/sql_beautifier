# frozen_string_literal: true

RSpec.describe "trailing_semicolon configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.trailing_semicolon = config_value
    end
  end

  ############################################################################
  ## trailing_semicolon: true (default)
  ############################################################################

  context "when trailing_semicolon is true (default)" do
    let(:config_value) { true }

    context "with a simple compact query" do
      let(:value) { "SELECT id FROM users" }

      it "appends a semicolon after the last clause" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with a multi-clause query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "appends a semicolon after the last clause" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true;
        SQL
      end
    end

    context "with a query that has all clauses" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department ORDER BY name LIMIT 25" }

      it "appends a semicolon after limit" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u

          where   active = true

          group by department

          order by name

          limit 25;
        SQL
      end
    end

    context "with a compact query with ORDER BY and LIMIT" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25" }

      it "appends a semicolon after limit" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          order by created_at desc
          limit 25;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE users.active = true" }

      it "appends a semicolon after the last clause" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id

          where   u.active = true;
        SQL
      end
    end

    context "with a subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "appends a semicolon after the closing parenthesis" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                  );
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active_users AS (SELECT id FROM users WHERE active = true) SELECT * FROM active_users" }

      it "appends a semicolon after the main query" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active_users as (
                      select  id
                      from    Users u
                      where   active = true
                  )

          select  *
          from    Active_Users au;
        SQL
      end
    end

    context "with multiple CTEs" do
      let(:value) { "WITH active_users AS (SELECT id FROM users WHERE active = true), recent_orders AS (SELECT user_id, total FROM orders) SELECT au.id, ro.total FROM active_users au INNER JOIN recent_orders ro ON ro.user_id = au.id" }

      it "appends a semicolon only at the end of the main query" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active_users as (
                      select  id
                      from    Users u
                      where   active = true
                  ),
                  recent_orders as (
                      select  user_id,
                              total

                      from    Orders o
                  )

          select  au.id,
                  ro.total

          from    Active_Users au
                  inner join Recent_Orders ro on ro.user_id = au.id;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "appends a semicolon after the closing parenthesis" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          );
        SQL
      end
    end

    context "with a CREATE TABLE AS without parentheses" do
      let(:value) { "CREATE TEMP TABLE foo AS SELECT id FROM users" }

      it "appends a semicolon after the closing parenthesis" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          );
        SQL
      end
    end

    context "with an input that already has a trailing semicolon" do
      let(:value) { "SELECT id FROM users;" }

      it "produces the same output as without the input semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with an unrecognized statement" do
      let(:value) { "EXPLAIN ANALYZE something" }

      it "appends a semicolon to the normalized output" do
        expect(output).to match_formatted_text(<<~SQL)
          explain analyze something;
        SQL
      end
    end

    context "with two semicolon-separated statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      it "appends a semicolon after each statement with a blank line between" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with two concatenated statements" do
      let(:value) { "SELECT id FROM constituents SELECT id FROM departments" }

      it "appends a semicolon after each detected statement" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with three semicolon-separated statements" do
      let(:value) { "SELECT id FROM users; SELECT id FROM orders; SELECT id FROM products" }

      it "appends a semicolon after each statement" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;

          select  id
          from    Orders o;

          select  id
          from    Products p;
        SQL
      end
    end

    context "with a complex multi-clause statement followed by a simple one" do
      let(:value) { "SELECT id, name FROM users WHERE active = true ORDER BY name; SELECT id FROM departments" }

      it "formats each statement fully with trailing semicolons" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true

          order by name;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with a CTE statement followed by a simple statement" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active; SELECT id FROM departments" }

      it "formats the CTE and the separate statement with trailing semicolons" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active as (
                      select  id
                      from    Users u
                      where   active = true
                  )

          select  *
          from    Active a;

          select  id
          from    Departments d;
        SQL
      end
    end
  end

  ############################################################################
  ## trailing_semicolon: false
  ############################################################################

  context "when trailing_semicolon is false" do
    let(:config_value) { false }

    context "with a simple compact query" do
      let(:value) { "SELECT id FROM users" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with a multi-clause query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active_users AS (SELECT id FROM users WHERE active = true) SELECT * FROM active_users" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active_users as (
                      select  id
                      from    Users u
                      where   active = true
                  )

          select  *
          from    Active_Users au
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with a subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                  )
        SQL
      end
    end

    context "with two semicolon-separated statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      it "formats each statement without semicolons" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c

          select  id
          from    Departments d
        SQL
      end
    end

    context "with two concatenated statements" do
      let(:value) { "SELECT id FROM constituents SELECT id FROM departments" }

      it "formats each statement without semicolons" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c

          select  id
          from    Departments d
        SQL
      end
    end

    context "with an input that has a trailing semicolon" do
      let(:value) { "SELECT id FROM users;" }

      it "strips the semicolon and does not add one" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with an unrecognized statement" do
      let(:value) { "EXPLAIN ANALYZE something" }

      it "does not append a semicolon" do
        expect(output).to match_formatted_text(<<~SQL)
          explain analyze something
        SQL
      end
    end
  end
end
