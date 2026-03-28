# frozen_string_literal: true

RSpec.describe SqlBeautifier do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

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

    context "with a simple query" do
      let(:value) { "SELECT id FROM users" }

      it "formats the query with a trailing semicolon" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with :trailing_semicolon set to false" do
      let(:value) { "SELECT id FROM users" }

      before { SqlBeautifier.configure { |config| config.trailing_semicolon = false } }

      it "does not append a trailing semicolon" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with two semicolon-separated statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      it "formats each statement and separates with a blank line" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Constituents c;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with two concatenated statements without semicolons" do
      let(:value) { "SELECT id FROM constituents SELECT id FROM departments" }

      it "detects and formats each statement independently" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Constituents c;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with trailing_semicolon disabled and multiple statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      before { SqlBeautifier.configure { |config| config.trailing_semicolon = false } }

      it "separates statements with a blank line and no semicolons" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Constituents c

          select  id
          from    Departments d
        SQL
      end
    end
  end

  describe ".call with per-call config" do
    let(:value) { "SELECT id FROM users" }

    context "with a single override" do
      let(:output) { described_class.call(value, trailing_semicolon: false) }

      it "applies the override" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with multiple overrides" do
      let(:output) { described_class.call(value, trailing_semicolon: false, keyword_case: :upper) }

      it "applies all overrides" do
        expect(output).to eq(<<~SQL)
          SELECT  id
          FROM    Users u
        SQL
      end
    end

    context "when a global config is set" do
      before { described_class.configure { |config| config.keyword_case = :upper } }

      let(:output) { described_class.call(value, keyword_case: :lower) }

      it "overrides the global config" do
        expect(output).to include("select")
        expect(output).not_to include("SELECT")
      end
    end

    context "when the per-call config does not include a key" do
      before { described_class.configure { |config| config.trailing_semicolon = false } }

      let(:output) { described_class.call(value, keyword_case: :upper) }

      it "falls back to the global config for unspecified keys" do
        expect(output).to include("SELECT")
        expect(output).not_to include(";")
      end
    end

    context "with an unknown key" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, bogus_key: true) }.to raise_error(ArgumentError, %r{bogus_key})
      end
    end

    context "with nil config" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, nil) }.to raise_error(ArgumentError, %r{Hash})
      end
    end

    context "with a non-Hash config" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, "bad") }.to raise_error(ArgumentError, %r{Hash})
      end
    end

    context "when the call completes" do
      it "does not mutate the global configuration" do
        described_class.call(value, trailing_semicolon: false, keyword_case: :upper)

        expect(described_class.configuration.trailing_semicolon).to eq(true)
        expect(described_class.configuration.keyword_case).to eq(:lower)
      end
    end

    context "with an empty config hash" do
      let(:output) { described_class.call(value, {}) }

      it "behaves identically to calling without config" do
        expect(output).to eq(described_class.call(value))
      end
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(SqlBeautifier::Configuration)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.keyword_column_width = 12
      end

      expect(described_class.configuration.keyword_column_width).to eq(12)
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration with a fresh instance" do
      original = described_class.configuration
      described_class.configure { |config| config.keyword_column_width = 12 }

      described_class.reset_configuration!

      expect(described_class.configuration).not_to equal(original)
      expect(described_class.configuration.keyword_column_width).to eq(8)
    end
  end

  ############################################################################
  ## Comment Preservation
  ############################################################################

  describe "comment preservation" do
    let(:output) { described_class.call(value) }

    context "with a banner comment before a statement" do
      let(:value) { "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nSELECT id FROM users" }

      it "preserves the banner and formats the SQL" do
        expect(output).to eq(<<~SQL)
          --------------------------------------------------------------------------------
          -- Base Query (34ms)
          --------------------------------------------------------------------------------
          select  id
          from    Users u;
        SQL
      end
    end

    context "with a separate-line comment between two statements" do
      let(:value) { "SELECT id FROM users;\n-- second query\nSELECT name FROM departments" }

      it "preserves the comment between formatted statements" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u;

          -- second query
          select  name
          from    Departments d;
        SQL
      end
    end

    context "with an inline comment in a SELECT clause" do
      let(:value) { "SELECT id -- primary key\n, name FROM users" }

      it "preserves the inline comment" do
        expect(output).to eq(<<~SQL)
          select  id, -- primary key
                  name

          from    Users u;
        SQL
      end
    end

    context "with a separate-line and block comment in a compact query" do
      let(:value) { "-- Base Query\nSELECT id /* primary key */ FROM users WHERE active = true" }

      it "preserves both comments with compact spacing" do
        expect(output).to eq(<<~SQL)
          -- Base Query
          select  id /* primary key */
          from    Users u
          where   active = true;
        SQL
      end
    end

    context "with a block comment inline" do
      let(:value) { "SELECT /* main columns */ id, name FROM users" }

      it "preserves the block comment" do
        expect(output).to eq(<<~SQL)
          select  /* main columns */ id,
                  name

          from    Users u;
        SQL
      end
    end

    context "with removable_comment_types set to :all" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- table" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = :all } }

      it "strips all comments" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with removable_comment_types set to [:inline, :blocks]" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- table" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = %i[inline blocks] } }

      it "strips inline and block comments but preserves separate-line" do
        expect(output).not_to include("/* pk */")
        expect(output).not_to include("-- table")
        expect(output).to include("-- banner")
      end
    end

    context "with removable_comment_types set to [:separate_line]" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- inline" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = [:separate_line] } }

      it "strips separate-line comments but preserves inline and block" do
        expect(output).not_to include("-- banner")
        expect(output).to include("/* pk */")
        expect(output).to include("-- inline")
      end
    end

    context "with per-call config overriding removable_comment_types" do
      let(:value) { "-- banner\nSELECT id FROM users" }
      let(:output) { described_class.call(value, removable_comment_types: :all) }

      it "strips comments per the override" do
        expect(output).not_to include("-- banner")
      end
    end

    context "with comments inside string literals" do
      let(:value) { "SELECT * FROM users WHERE name = 'test--value' AND bio = 'has /* stars */'" }

      it "preserves comment-like characters inside strings" do
        expect(output).to include("'test--value'")
        expect(output).to include("'has /* stars */'")
      end
    end

    context "with an inline comment after a trailing semicolon" do
      let(:value) { "SELECT id FROM users; -- done" }

      it "preserves the inline comment" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u; -- done
        SQL
      end
    end

    context "with a comment-only input" do
      let(:value) { "-- just a comment" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  ############################################################################
  ## JOINs
  ############################################################################

  describe "JOINs" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with an INNER JOIN" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE users.active = true" }

      it "formats the query with aliases" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id

          where   u.active = true
        SQL
      end
    end

    context "with a LEFT OUTER JOIN" do
      let(:value) { "SELECT users.id, addresses.city FROM users LEFT OUTER JOIN addresses ON addresses.user_id = users.id" }

      it "formats the left outer join with aliases" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  a.city

          from    Users u
                  left outer join Addresses a on a.user_id = u.id
        SQL
      end
    end

    context "with a CROSS JOIN" do
      let(:value) { "SELECT users.id, roles.name FROM users CROSS JOIN roles" }

      it "formats the cross join without an ON clause" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  r.name

          from    Users u
                  cross join Roles r
        SQL
      end
    end

    context "with mixed join types" do
      let(:value) { "SELECT users.id, orders.total, payments.amount FROM users INNER JOIN orders ON orders.user_id = users.id LEFT JOIN payments ON payments.order_id = orders.id WHERE users.active = true" }

      it "formats each join type with aliases" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  o.total,
                  p.amount

          from    Users u
                  inner join Orders o on o.user_id = u.id
                  left join Payments p on p.order_id = o.id

          where   u.active = true
        SQL
      end
    end

    context "with a multi-condition ON clause" do
      let(:value) { "SELECT users.id FROM users INNER JOIN orders ON orders.user_id = users.id AND orders.status = 'active' WHERE users.verified = true AND orders.total > 50" }

      it "formats join conditions and WHERE conditions independently" do
        expect(output).to eq(<<~SQL)
          select  u.id

          from    Users u
                  inner join Orders o on o.user_id = u.id
                      and o.status = 'active'

          where   u.verified = true
                  and o.total > 50
        SQL
      end
    end

    context "with conflicting table aliases" do
      let(:value) { "SELECT updates.id, uploads.path FROM updates INNER JOIN uploads ON uploads.update_id = updates.id" }

      it "disambiguates aliases with counters" do
        expect(output).to eq(<<~SQL)
          select  u1.id,
                  u2.path

          from    Updates u1
                  inner join Uploads u2 on u2.update_id = u1.id
        SQL
      end
    end

    context "with explicit aliases in the input query" do
      let(:value) { "SELECT users.id, orders.total FROM users usr INNER JOIN orders o ON o.user_id = usr.id WHERE users.active = true" }

      it "preserves explicit aliases across the full output" do
        expect(output).to eq(<<~SQL)
          select  usr.id,
                  o.total

          from    Users usr
                  inner join Orders o on o.user_id = usr.id

          where   usr.active = true
        SQL
      end
    end
  end

  ############################################################################
  ## Subqueries
  ############################################################################

  describe "subqueries" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with a subquery in the WHERE clause" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "formats the subquery with indentation" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                  )
        SQL
      end
    end

    context "with a subquery in the SELECT clause" do
      let(:value) { "SELECT id, (SELECT count(*) FROM orders WHERE orders.user_id = users.id) FROM users" }

      it "formats the subquery with indentation" do
        expect(output).to eq(<<~SQL)
          select  id,
                  (
              select  count(*)
              from    Orders o
              where   o.user_id = u.id
          )

          from    Users u
        SQL
      end
    end

    context "with nested subqueries" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE product_id IN (SELECT id FROM products WHERE active = true))" }

      it "formats both levels of subqueries" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                      where   product_id in (
                                              select  id
                                              from    Products p
                                              where   active = true
                                          )
                  )
        SQL
      end
    end

    context "with a subquery containing a JOIN" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT orders.user_id FROM orders INNER JOIN products ON products.id = orders.product_id)" }

      it "formats the subquery with JOIN indentation" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  o.user_id

                      from    Orders o
                              inner join Products p on p.id = o.product_id
                  )
        SQL
      end
    end
  end

  ############################################################################
  ## CTEs
  ############################################################################

  describe "CTEs" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with a single CTE" do
      let(:value) { "WITH active_users AS (SELECT id, name FROM users WHERE active = true) SELECT * FROM active_users" }

      it "formats the CTE and main query" do
        expect(output).to eq(<<~SQL)
          with    active_users as (
                      select  id,
                              name

                      from    Users u

                      where   active = true
                  )

          select  *
          from    Active_Users au
        SQL
      end
    end

    context "with multiple CTEs" do
      let(:value) { "WITH active_users AS (SELECT id FROM users WHERE active = true), recent_orders AS (SELECT user_id, total FROM orders) SELECT au.id, ro.total FROM active_users au INNER JOIN recent_orders ro ON ro.user_id = au.id" }

      it "formats each CTE and the main query" do
        expect(output).to eq(<<~SQL)
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
                  inner join Recent_Orders ro on ro.user_id = au.id
        SQL
      end
    end

    context "with a recursive CTE" do
      let(:value) { "WITH RECURSIVE numbers AS (SELECT 1 AS n) SELECT * FROM numbers" }

      it "formats with the recursive keyword" do
        expect(output).to eq(<<~SQL)
          with    recursive numbers as (
                      select  1 as n
                  )

          select  *
          from    Numbers n
        SQL
      end
    end

    context "with a materialized CTE" do
      let(:value) { "WITH cte AS MATERIALIZED (SELECT id FROM users) SELECT * FROM cte" }

      it "preserves the materialized keyword" do
        expect(output).to eq(<<~SQL)
          with    cte as materialized (
                      select  id
                      from    Users u
                  )

          select  *
          from    Cte c
        SQL
      end
    end

    context "with a not materialized CTE" do
      let(:value) { "WITH cte AS NOT MATERIALIZED (SELECT id FROM users) SELECT * FROM cte" }

      it "preserves the not materialized keywords" do
        expect(output).to eq(<<~SQL)
          with    cte as not materialized (
                      select  id
                      from    Users u
                  )

          select  *
          from    Cte c
        SQL
      end
    end

    context "with a CTE with a column list" do
      let(:value) { "WITH cte(a, b) AS (SELECT 1, 2) SELECT * FROM cte" }

      it "preserves the column list in the header" do
        expect(output).to eq(<<~SQL)
          with    cte (a, b) as (
                      select  1,
                              2
                  )

          select  *
          from    Cte c
        SQL
      end
    end

    context "with a CTE containing a subquery" do
      let(:value) { "WITH filtered AS (SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)) SELECT * FROM filtered" }

      it "formats the CTE body and the nested subquery" do
        expect(output).to eq(<<~SQL)
          with    filtered as (
                      select  id
                      from    Users u
                      where   id in (
                                  select  user_id
                                  from    Orders o
                              )
                  )

          select  *
          from    Filtered f
        SQL
      end
    end

    context "with a CTE containing JOINs" do
      let(:value) { "WITH order_details AS (SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE orders.total > 100) SELECT * FROM order_details" }

      it "formats the CTE body with JOIN and alias handling" do
        expect(output).to eq(<<~SQL)
          with    order_details as (
                      select  u.id,
                              o.total

                      from    Users u
                              inner join Orders o on o.user_id = u.id

                      where   o.total > 100
                  )

          select  *
          from    Order_Details od
        SQL
      end
    end
  end

  ############################################################################
  ## CREATE TABLE AS
  ############################################################################

  describe "CREATE TABLE AS" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with a simple CREATE TEMP TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "formats the preamble and indented body" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with a CREATE TABLE AS without parentheses" do
      let(:value) { "CREATE TEMP TABLE foo AS SELECT id FROM users" }

      it "wraps the body in parentheses" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with CREATE TABLE AS IF NOT EXISTS" do
      let(:value) { "CREATE TEMP TABLE IF NOT EXISTS foo AS (SELECT id FROM users)" }

      it "includes if not exists in the preamble" do
        expect(output).to eq(<<~SQL)
          create temp table if not exists Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with WITH DATA suffix" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users) WITH DATA" }

      it "preserves the WITH DATA suffix" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          ) with data
        SQL
      end
    end

    context "with WITH NO DATA suffix" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users) WITH NO DATA" }

      it "preserves the WITH NO DATA suffix" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          ) with no data
        SQL
      end
    end

    context "with a CTE inside the body" do
      let(:value) { "CREATE TEMP TABLE foo AS (WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active)" }

      it "formats the CTE inside the body" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              with    active as (
                          select  id
                          from    Users u
                          where   active = true
                      )

              select  *
              from    Active a
          )
        SQL
      end
    end
  end

  ############################################################################
  ## Complex WHERE Conditions
  ############################################################################

  describe "complex WHERE conditions" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with parenthesized groups" do
      let(:value) { "SELECT id FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator') AND verified = true" }

      it "expands parenthesized groups and formats conditions" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (
                      role = 'admin'
                      or role = 'moderator'
                  )
                  and verified = true
        SQL
      end
    end

    context "with BETWEEN...AND" do
      let(:value) { "SELECT id FROM users WHERE created_at BETWEEN '2025-01-01' AND '2025-12-31' AND active = true" }

      it "treats the AND inside BETWEEN as part of the BETWEEN expression" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   created_at between '2025-01-01' and '2025-12-31'
                  and active = true
        SQL
      end
    end
  end

  ############################################################################
  ## DISTINCT
  ############################################################################

  describe "DISTINCT" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with DISTINCT" do
      let(:value) { "SELECT DISTINCT name FROM users ORDER BY name" }

      it "formats the DISTINCT prefix with the select clause" do
        expect(output).to eq(<<~SQL)
          select  distinct
                  name

          from    Users u

          order by name
        SQL
      end
    end

    context "with DISTINCT ON" do
      let(:value) { "SELECT DISTINCT ON (users.department) users.id, users.name FROM users ORDER BY users.department, users.name" }

      it "formats the DISTINCT ON prefix with alias replacement" do
        expect(output).to eq(<<~SQL)
          select  distinct on (u.department)
                  u.id,
                  u.name

          from    Users u

          order by u.department, u.name
        SQL
      end
    end
  end

  ############################################################################
  ## Full Pipeline
  ############################################################################

  describe "full pipeline" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with all clauses" do
      let(:value) { "SELECT department, count(*), avg(salary) FROM employees WHERE active = true GROUP BY department HAVING count(*) > 5 AND avg(salary) > 50000 ORDER BY count(*) DESC LIMIT 10" }

      it "produces formatted output with all clauses" do
        expect(output).to eq(<<~SQL)
          select  department,
                  count(*),
                  avg(salary)

          from    Employees e

          where   active = true

          group by department

          having  count(*) > 5
                  and avg(salary) > 50000

          order by count(*) desc

          limit 10
        SQL
      end
    end
  end

  ############################################################################
  ## CASE Expressions
  ############################################################################

  describe "CASE expressions" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with a searched CASE in SELECT" do
      let(:value) { "SELECT id, CASE WHEN status = 1 THEN 'active' WHEN status = 2 THEN 'inactive' ELSE 'unknown' END AS label FROM users" }

      it "preserves the CASE expression inline" do
        expect(output).to eq(<<~SQL)
          select  id,
                  case when status = 1 then 'active' when status = 2 then 'inactive' else 'unknown' end as label

          from    Users u
        SQL
      end
    end

    context "with a simple CASE in SELECT" do
      let(:value) { "SELECT CASE status WHEN 1 THEN 'active' ELSE 'unknown' END FROM users" }

      it "preserves the CASE expression inline" do
        expect(output).to eq(<<~SQL)
          select  case status when 1 then 'active' else 'unknown' end
          from    Users u
        SQL
      end
    end

    context "with a CASE expression in WHERE" do
      let(:value) { "SELECT id FROM users WHERE CASE WHEN role = 'admin' THEN true ELSE false END = true" }

      it "preserves the CASE expression in the WHERE clause" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   case when role = 'admin' then true else false end = true
        SQL
      end
    end
  end

  ############################################################################
  ## Window Functions
  ############################################################################

  describe "window functions" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with ROW_NUMBER and PARTITION BY" do
      let(:value) { "SELECT id, name, ROW_NUMBER() OVER (PARTITION BY department ORDER BY created_at DESC) AS row_num FROM users" }

      it "preserves the window function inline" do
        expect(output).to eq(<<~SQL)
          select  id,
                  name,
                  row_number() over (partition by department order by created_at desc) as row_num

          from    Users u
        SQL
      end
    end

    context "with a window function without PARTITION BY" do
      let(:value) { "SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) AS row_num FROM users" }

      it "preserves the window function inline" do
        expect(output).to eq(<<~SQL)
          select  id,
                  row_number() over (order by created_at) as row_num

          from    Users u
        SQL
      end
    end
  end

  ############################################################################
  ## Set Operators (UNION, INTERSECT, EXCEPT)
  ############################################################################

  describe "set operators" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with UNION ALL" do
      let(:value) { "SELECT id, name FROM users WHERE active = true UNION ALL SELECT id, name FROM archived_users WHERE active = true" }

      it "formats both sides of the UNION ALL" do
        expect(output).to eq(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true union all

          select  id,
                  name

          from    Archived_Users au

          where   active = true
        SQL
      end
    end

    context "with a simple UNION" do
      let(:value) { "SELECT id FROM users UNION SELECT id FROM departments" }

      it "formats both sides of the UNION" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users union

          select  id
          from    Departments d
        SQL
      end
    end

    context "with INTERSECT" do
      let(:value) { "SELECT id FROM users INTERSECT SELECT id FROM departments" }

      it "formats both sides of the INTERSECT" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users intersect

          select  id
          from    Departments d
        SQL
      end
    end

    context "with EXCEPT" do
      let(:value) { "SELECT id FROM users EXCEPT SELECT id FROM departments" }

      it "formats both sides of the EXCEPT" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users except

          select  id
          from    Departments d
        SQL
      end
    end
  end

  ############################################################################
  ## OFFSET
  ############################################################################

  describe "OFFSET" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with LIMIT and OFFSET" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25 OFFSET 50" }

      it "formats the query with LIMIT and OFFSET" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          order by created_at desc
          limit 25 offset 50
        SQL
      end
    end
  end

  ############################################################################
  ## Type Casting
  ############################################################################

  describe "type casting" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with CAST expression" do
      let(:value) { "SELECT CAST(created_at AS date), name FROM users" }

      it "preserves the CAST expression" do
        expect(output).to eq(<<~SQL)
          select  cast(created_at as date),
                  name

          from    Users u
        SQL
      end
    end

    context "with PostgreSQL :: cast" do
      let(:value) { "SELECT id::text, created_at::date FROM users" }

      it "preserves the :: cast syntax" do
        expect(output).to eq(<<~SQL)
          select  id::text,
                  created_at::date

          from    Users u
        SQL
      end
    end

    context "with CAST in WHERE" do
      let(:value) { "SELECT id FROM users WHERE CAST(score AS integer) > 50" }

      it "preserves the CAST in the WHERE clause" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   cast(score as integer) > 50
        SQL
      end
    end
  end

  ############################################################################
  ## Implicit Joins (Comma-Separated FROM)
  ############################################################################

  describe "implicit joins" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with comma-separated tables in FROM" do
      let(:value) { "SELECT users.id, orders.total FROM users, orders WHERE orders.user_id = users.id AND users.active = true" }

      it "formats the query with comma-separated tables" do
        expect(output).to eq(<<~SQL)
          select  users.id,
                  orders.total

          from    Users, orders

          where   orders.user_id = users.id
                  and users.active = true
        SQL
      end
    end
  end

  ############################################################################
  ## Edge Cases
  ############################################################################

  describe "edge cases" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with non-SQL input" do
      let(:value) { "EXPLAIN ANALYZE something" }

      it "returns normalized text" do
        expect(output).to eq("explain analyze something\n")
      end
    end

    context "with a prefix before the first clause" do
      let(:value) { "EXPLAIN SELECT id FROM users" }

      it "returns normalized text" do
        expect(output).to eq("explain select id from users\n")
      end
    end
  end

  ############################################################################
  ## Configuration Variations
  ############################################################################

  describe "configuration variations" do
    context "with keyword_case: :upper" do
      let(:output) { described_class.call("SELECT id, name FROM users WHERE active = true", keyword_case: :upper, trailing_semicolon: false) }

      it "uppercases keywords" do
        expect(output).to eq(<<~SQL)
          SELECT  id,
                  name

          FROM    Users u

          WHERE   active = true
        SQL
      end
    end

    context "with keyword_column_width: 12" do
      let(:output) { described_class.call("SELECT id, name FROM users WHERE active = true", keyword_column_width: 12, trailing_semicolon: false) }

      it "widens the keyword column" do
        expect(output).to eq(<<~SQL)
          select      id,
                      name

          from        Users u

          where       active = true
        SQL
      end
    end

    context "with indent_spaces: 2" do
      let(:output) { described_class.call("SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)", indent_spaces: 2, trailing_semicolon: false) }

      it "uses 2-space indentation for subqueries" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   id in (
                    select  user_id
                    from    Orders o
                  )
        SQL
      end
    end

    context "with clause_spacing_mode: :spacious" do
      let(:output) { described_class.call("SELECT id FROM users WHERE active = true", clause_spacing_mode: :spacious, trailing_semicolon: false) }

      it "adds blank lines between all clauses" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
        SQL
      end
    end

    context "with table_name_format: :lowercase" do
      let(:output) { described_class.call("SELECT id FROM users", table_name_format: :lowercase, trailing_semicolon: false) }

      it "keeps table names lowercase" do
        expect(output).to eq(<<~SQL)
          select  id
          from    users u
        SQL
      end
    end

    context "with alias_strategy: :none" do
      let(:output) { described_class.call("SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id", alias_strategy: :none, trailing_semicolon: false) }

      it "does not generate aliases" do
        expect(output).to eq(<<~SQL)
          select  users.id,
                  orders.total

          from    Users
                  inner join Orders on orders.user_id = users.id
        SQL
      end
    end

    context "with inline_group_threshold: 60" do
      let(:output) { described_class.call("SELECT id FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')", inline_group_threshold: 60, trailing_semicolon: false) }

      it "keeps short groups inline" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator')
        SQL
      end
    end
  end
end
