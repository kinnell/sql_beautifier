# frozen_string_literal: true

RSpec.describe SqlBeautifier::Formatter do
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
      let(:value) { " " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a single-line query" do
      let(:value) { "SELECT id FROM users" }

      it "returns the formatted query" do
        expect(output).to eq("select  id\nfrom    Users u\n")
      end
    end

    context "with a simple query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "formats select clause" do
        expect(output).to include("select  id,")
        expect(output).to include("        name")
      end

      it "formats from clause with PascalCase and alias" do
        expect(output).to include("from    Users u")
      end

      it "formats where clause" do
        expect(output).to include("where   active = true")
      end
    end

    context "when the value has a limit clause" do
      let(:value) { "SELECT id FROM users LIMIT 10" }

      it "formats limit as a separate clause" do
        expect(output).to include("limit 10")
      end

      it "keeps compact spacing for a simple query with limit" do
        expect(output).to include("from    Users u\nlimit 10")
      end
    end

    context "when the value has an order by clause" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC" }

      it "formats order by clause" do
        expect(output).to include("order by created_at desc")
      end
    end

    context "when the value has a group by and having clause" do
      let(:value) { "SELECT status, count(*) FROM users GROUP BY status HAVING count(*) > 5" }

      it "formats group by" do
        expect(output).to include("group by status")
      end

      it "formats having" do
        expect(output).to include("having  count(*) > 5")
      end
    end

    context "when the value has a string literal" do
      let(:value) { "SELECT * FROM users WHERE name = 'John DOE'" }

      it "preserves case inside strings" do
        expect(output).to include("'John DOE'")
      end
    end

    context "when the value has multiple clauses" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "separates clauses with blank lines" do
        expect(output).to include("name\n\nfrom")
        expect(output).to include("Users u\n\nwhere")
      end
    end

    context "when the value has all clauses" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department ORDER BY name LIMIT 25" }

      it "produces the expected full output" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true

          group by department

          order by name

          limit 25
        SQL
      end
    end

    context "when the value has a subquery in the where clause" do
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

    context "when the value has a subquery in the select clause" do
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

    context "when the value has multiple string literals" do
      let(:value) { "SELECT * FROM users WHERE first_name = 'Alice' AND last_name = 'DOE'" }

      it "preserves case inside all string literals" do
        expect(output).to include("'Alice'")
        expect(output).to include("'DOE'")
      end
    end

    context "when the value has no recognized clauses" do
      let(:value) { "EXPLAIN ANALYZE something" }

      it "returns the normalized value with a trailing newline" do
        expect(output).to eq("explain analyze something\n")
      end
    end

    context "when the value has a prefix before the first clause" do
      let(:value) { "EXPLAIN SELECT id FROM users" }

      it "returns the normalized value with a trailing newline" do
        expect(output).to eq("explain select id from users\n")
      end
    end

    context "when the value has an empty select body" do
      let(:value) { "SELECT FROM users" }

      it "formats without error" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a JOIN query" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE users.active = true" }

      it "formats with PascalCase tables, aliases, and JOIN on continuation line" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id

          where   u.active = true
        SQL
      end
    end

    context "with tab and newline whitespace in input" do
      let(:value) { "SELECT\tid,\tname\nFROM\tusers\nWHERE\tactive = true" }

      it "normalizes whitespace and formats correctly" do
        expect(output).to eq(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true
        SQL
      end
    end

    context "with a cross join" do
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

    context "with a complex real-world query" do
      let(:value) do
        <<~SQL.chomp
          SELECT users.id, users.name, orders.total, products.name
          FROM users
          INNER JOIN orders ON orders.user_id = users.id
          INNER JOIN products ON products.id = orders.product_id
          WHERE users.active = true AND orders.total > 100
          ORDER BY orders.total DESC
          LIMIT 25
        SQL
      end

      it "produces fully formatted output with aliases throughout" do
        expect(output).to eq(<<~SQL)
          select  u.id,
                  u.name,
                  o.total,
                  p.name

          from    Users u
                  inner join Orders o on o.user_id = u.id
                  inner join Products p on p.id = o.product_id

          where   u.active = true
                  and o.total > 100

          order by o.total desc

          limit 25
        SQL
      end
    end

    ############################################################################
    ## DISTINCT Integration
    ############################################################################

    context "with a DISTINCT query" do
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

    context "with a DISTINCT ON query" do
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

    ############################################################################
    ## Join Type Integration
    ############################################################################

    context "with a left outer join" do
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

    ############################################################################
    ## Complex WHERE Integration
    ############################################################################

    context "with parenthesized groups in WHERE" do
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

    context "with a parenthesized OR group inside a WHERE clause" do
      let(:value) { "SELECT * FROM Departments WHERE departments.id.enabled = true AND (departments.id IS NULL OR departments.id.exportable = true)" }

      it "expands the parenthesized group with alias replacement" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Departments d

          where   d.id.enabled = true
                  and (
                      d.id is null
                      or d.id.exportable = true
                  )
        SQL
      end
    end

    context "with a multi-condition join and WHERE conditions" do
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

    ############################################################################
    ## Full Pipeline
    ############################################################################

    context "with GROUP BY, HAVING, and aggregate functions" do
      let(:value) { "SELECT department, count(*), avg(salary) FROM employees WHERE active = true GROUP BY department HAVING count(*) > 5 AND avg(salary) > 50000 ORDER BY count(*) DESC LIMIT 10" }

      it "produces fully formatted output with all clauses" do
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

    ############################################################################
    ## Subquery Integration
    ############################################################################

    context "with a nested subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE product_id IN (SELECT id FROM products WHERE active = true))" }

      it "formats both levels of subqueries" do
        expect(output).to include("where   id in (")
        expect(output).to include("  select  user_id")
        expect(output).to include("  where   product_id in (")
        expect(output).to include("    select  id")
      end
    end

    context "with a subquery and its own JOIN" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT orders.user_id FROM orders INNER JOIN products ON products.id = orders.product_id)" }

      it "formats the subquery with JOIN indentation" do
        expect(output).to include("where   id in (")
        expect(output).to include("  select  o.user_id")
        expect(output).to include("  from    Orders o")
        expect(output).to include("          inner join Products p on p.id = o.product_id")
      end
    end

    ############################################################################
    ## CTE Integration
    ############################################################################

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

    context "with a CTE containing joins and conditions" do
      let(:value) { "WITH order_details AS (SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE orders.total > 100) SELECT * FROM order_details" }

      it "formats the CTE body with join and alias handling" do
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

    context "with a CTE containing a subquery" do
      let(:value) { "WITH filtered AS (SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)) SELECT * FROM filtered" }

      it "formats both the CTE body and the nested subquery" do
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

    context "with a CTE where strings contain SQL keywords" do
      let(:value) { "WITH labeled AS (SELECT id, name FROM users WHERE name = 'with as select') SELECT * FROM labeled" }

      it "preserves string literals and formats correctly" do
        expect(output).to include("where   name = 'with as select'")
        expect(output).to start_with("with    labeled as (")
      end
    end

    context "with a recursive CTE" do
      let(:value) { "WITH RECURSIVE numbers AS (SELECT 1 AS n) SELECT * FROM numbers" }

      it "formats with the recursive keyword" do
        expect(output).to start_with("with    recursive numbers as (")
        expect(output).to include("select  *\nfrom    Numbers n")
      end
    end

    context "with a recursive CTE with a SEARCH clause" do
      let(:value) { "WITH RECURSIVE cte AS (SELECT id FROM nodes) SEARCH DEPTH FIRST BY id SET order_col SELECT * FROM cte" }

      it "preserves the SEARCH clause while formatting the CTE body" do
        expect(output).to eq(<<~SQL)
          with    recursive cte as (
                      select  id
                      from    Nodes n
                  )

          search depth first by id set order_col select * from cte
        SQL
      end
    end

    context "with a recursive CTE with SEARCH and CYCLE clauses" do
      let(:value) { "WITH RECURSIVE cte AS (SELECT id, parent_id FROM nodes) SEARCH DEPTH FIRST BY id SET order_col CYCLE id SET is_cycle USING cycle_path SELECT * FROM cte" }

      it "preserves SEARCH and CYCLE clauses while formatting the CTE body" do
        expect(output).to eq(<<~SQL)
          with    recursive cte as (
                      select  id,
                              parent_id

                      from    Nodes n
                  )

          search depth first by id set order_col cycle id set is_cycle using cycle_path select * from cte
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

    context "with a materialized CTE" do
      let(:value) { "WITH cte AS MATERIALIZED (SELECT id FROM users) SELECT * FROM cte" }

      it "formats the CTE and preserves the :materialized keyword" do
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

      it "formats the CTE and preserves the :not materialized keywords" do
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

    ############################################################################
    ## CREATE TABLE AS Integration
    ############################################################################

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

    context "with a CREATE TABLE AS with JOINs and complex WHERE" do
      let(:value) do
        <<~SQL.chomp
          create temp table tmp_export_constituent_ids as (
            select distinct constituents.id
            from constituents
            inner join person_matches on person_matches.record_id = constituents.id
              and person_matches.record_type = 'Constituent'
              and person_matches.matched_record_type = 'ExternalConstituent'
              and person_matches.score > 0.99
              and person_matches.health_system_id = constituents.health_system_id
            inner join external_constituents on external_constituents.id = person_matches.matched_record_id
            inner join encounters on encounters.constituent_id = constituents.id
            left join departments on departments.name = encounters.department
            left join facilities on facilities.id = departments.facility_id
            where constituents.health_system_id = 12
              and constituents.suppressed != true
              and constituents.is_deceased != true
              and encounters.discharged_at >= '2026-02-01 00:00:00'
              and encounters.discharged_at <= '2026-03-26 00:00:00'
          )
        SQL
      end

      it "starts with the PascalCase preamble" do
        expect(output).to start_with("create temp table Tmp_Export_Constituent_Ids as (")
      end

      it "formats the body with DISTINCT" do
        expect(output).to include("    select  distinct\n            c.id")
      end

      it "formats joins with aliases" do
        expect(output).to include("inner join Person_Matches pm on pm.record_id = c.id")
        expect(output).to include("inner join External_Constituents ec on ec.id = pm.matched_record_id")
        expect(output).to include("inner join Encounters e on e.constituent_id = c.id")
        expect(output).to include("left join Departments d on d.name = e.department")
        expect(output).to include("left join Facilities f on f.id = d.facility_id")
      end

      it "formats WHERE conditions with aliases" do
        expect(output).to include("where   c.health_system_id = 12")
        expect(output).to include("and c.suppressed != true")
        expect(output).to include("and e.discharged_at >= '2026-02-01 00:00:00'")
      end

      it "closes with a parenthesis" do
        expect(output.strip).to end_with(")")
      end
    end

    context "with a CREATE TABLE AS containing a CTE body" do
      let(:value) { "CREATE TEMP TABLE foo AS (WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active)" }

      it "formats the CTE inside the body" do
        expect(output).to start_with("create temp table Foo as (")
        expect(output).to include("with    active as (")
        expect(output).to include("select  *")
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

    ############################################################################
    ## Configuration Integration
    ############################################################################

    context "with :keyword_column_width set to 10" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      before { SqlBeautifier.configure { |config| config.keyword_column_width = 10 } }

      it "pads keywords to the custom width" do
        expect(output).to include("select    id,")
        expect(output).to include("          name")
        expect(output).to include("from      Users u")
        expect(output).to include("where     active = true")
      end
    end

    context "with :table_name_format set to :lowercase" do
      let(:value) { "SELECT id FROM users INNER JOIN orders ON orders.user_id = users.id" }

      before { SqlBeautifier.configure { |config| config.table_name_format = :lowercase } }

      it "produces lowercase table names" do
        expect(output).to include("from    users u")
        expect(output).to include("inner join orders o")
      end
    end

    context "with :alias_strategy set to :none" do
      let(:value) { "SELECT users.id FROM users WHERE users.active = true" }

      before { SqlBeautifier.configure { |config| config.alias_strategy = :none } }

      it "produces output without aliases" do
        expect(output).to eq(<<~SQL)
          select  users.id
          from    Users
          where   users.active = true
        SQL
      end
    end

    context "with a callable :alias_strategy" do
      let(:value) { "SELECT users.id FROM users WHERE users.active = true" }

      before do
        SqlBeautifier.configure do |config|
          config.alias_strategy = ->(table_name) { "tbl_#{table_name[0]}" }
        end
      end

      it "uses the callable for alias generation" do
        expect(output).to include("from    Users tbl_u")
        expect(output).to include("tbl_u.id")
        expect(output).to include("tbl_u.active")
      end
    end

    ############################################################################
    ## :inline_group_threshold Integration
    ############################################################################

    context "with :inline_group_threshold set to 0" do
      let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

      before { SqlBeautifier.configure { |config| config.inline_group_threshold = 0 } }

      it "always expands parenthesized groups" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (
                      role = 'admin'
                      or role = 'moderator'
                  )
        SQL
      end
    end

    context "with :inline_group_threshold below the inline group length" do
      let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

      before { SqlBeautifier.configure { |config| config.inline_group_threshold = 37 } }

      it "expands the group to multiple lines" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (
                      role = 'admin'
                      or role = 'moderator'
                  )
        SQL
      end
    end

    context "with :inline_group_threshold equal to the inline group length" do
      let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

      before { SqlBeautifier.configure { |config| config.inline_group_threshold = 38 } }

      it "keeps the group inline" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator')
        SQL
      end
    end

    context "with :inline_group_threshold above the inline group length" do
      let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

      before { SqlBeautifier.configure { |config| config.inline_group_threshold = 100 } }

      it "keeps the group inline" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator')
        SQL
      end
    end

    context "with :inline_group_threshold and a group that exceeds it" do
      let(:value) { "SELECT * FROM users WHERE active = true AND (very_long_column_alpha = 'some_long_value' OR very_long_column_beta = 'another_long_value')" }

      before { SqlBeautifier.configure { |config| config.inline_group_threshold = 60 } }

      it "expands the long group while the threshold allows shorter ones" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (
                      very_long_column_alpha = 'some_long_value'
                      or very_long_column_beta = 'another_long_value'
                  )
        SQL
      end
    end

    ############################################################################
    ## Normalizer Integration
    ############################################################################

    context "with a trailing semicolon" do
      let(:value) { "SELECT id FROM users;" }

      it "strips the semicolon and formats normally" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with SQL comments" do
      let(:value) { "SELECT id /* primary key */ FROM users -- the table\nWHERE active = true" }

      it "strips comments and formats normally" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   active = true
        SQL
      end
    end

    context "with :clause_spacing_mode set to :spacious" do
      let(:value) { "SELECT id FROM users WHERE active = true" }

      before { SqlBeautifier.configure { |config| config.clause_spacing_mode = :spacious } }

      it "keeps blank lines between all top-level clauses" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
        SQL
      end
    end

    context "with compact spacing defaults and multiple where conditions" do
      let(:value) { "SELECT id FROM users WHERE active = true AND verified = true" }

      it "keeps blank lines between clauses because the where clause is not simple" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and verified = true
        SQL
      end
    end

    context "with compact spacing defaults and order by and limit" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25" }

      it "keeps all top-level clauses on single newlines" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          order by created_at desc
          limit 25
        SQL
      end
    end
  end
end
