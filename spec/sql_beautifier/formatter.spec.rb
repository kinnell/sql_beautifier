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
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
        SQL
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
        expect(output).to include(<<~SQL.chomp)
          from    Users u
          limit 10
        SQL
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
        expect(output).to include(<<~SQL.chomp)
          name

          from
        SQL
        expect(output).to include(<<~SQL.chomp)
          Users u

          where
        SQL
      end
    end

    context "when the value has all clauses" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department ORDER BY name LIMIT 25" }

      it "produces the expected full output" do
        expect(output).to match_formatted_text(<<~SQL)
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

    context "when the value has a subquery in the select clause" do
      let(:value) { "SELECT id, (SELECT count(*) FROM orders WHERE orders.user_id = users.id) FROM users" }

      it "formats the subquery with indentation" do
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
          explain analyze something
        SQL
      end
    end

    context "when the value has a prefix before the first clause" do
      let(:value) { "EXPLAIN SELECT id FROM users" }

      it "returns the normalized value with a trailing newline" do
        expect(output).to match_formatted_text(<<~SQL)
          explain select id from users
        SQL
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
          select  usr.id,
                  o.total

          from    Users usr
                  inner join Orders o on o.user_id = usr.id

          where   usr.active = true
        SQL
      end
    end

    ############################################################################
    ## LATERAL Join Integration
    ############################################################################

    context "with an inner join lateral" do
      let(:value) { "SELECT users.id, recent_orders.total FROM users INNER JOIN LATERAL (SELECT total FROM orders WHERE orders.user_id = users.id ORDER BY created_at DESC LIMIT 1) AS recent_orders ON true" }

      it "formats the lateral join with the subquery" do
        expect(output).to include("inner join lateral (")
        expect(output).to include(") recent_orders on true")
      end

      it "formats the primary table normally" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a left join lateral" do
      let(:value) { "SELECT users.id, recent_orders.total FROM users LEFT JOIN LATERAL (SELECT total FROM orders WHERE orders.user_id = users.id LIMIT 1) AS recent_orders ON true" }

      it "formats the lateral join with the subquery" do
        expect(output).to include("left join lateral (")
        expect(output).to include(") recent_orders on true")
      end
    end

    context "with a lateral join alongside a regular join" do
      let(:value) { "SELECT users.id, profiles.bio, recent_orders.total FROM users INNER JOIN profiles ON profiles.user_id = users.id LEFT JOIN LATERAL (SELECT total FROM orders WHERE orders.user_id = users.id LIMIT 1) AS recent_orders ON true" }

      it "formats the regular join without lateral" do
        expect(output).to include("inner join Profiles p on p.user_id = u.id")
      end

      it "formats the lateral join" do
        expect(output).to include("left join lateral (")
      end
    end

    ############################################################################
    ## Complex WHERE Integration
    ############################################################################

    context "with parenthesized groups in WHERE" do
      let(:value) { "SELECT id FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator') AND verified = true" }

      it "expands parenthesized groups and formats conditions" do
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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

    context "with a derived table in the FROM clause" do
      let(:value) { "SELECT active_users.id FROM (SELECT id FROM users WHERE active = true) AS active_users" }

      it "formats the derived table as a subquery" do
        expect(output).to include("from    (")
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
        expect(output).to include("where   active = true")
        expect(output).to include(") active_users")
      end
    end

    context "with an aliasless derived table in the FROM clause" do
      let(:value) { "SELECT id FROM (SELECT id FROM users)" }

      it "formats the derived table without raising an error" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          select  id
          from    (
          ············select  id
          ············from    Users u
          ········)

        SQL
      end
    end

    context "with NOT EXISTS containing a derived table" do
      let(:value) { "SELECT users.id FROM users WHERE NOT EXISTS (SELECT 1 FROM (SELECT DISTINCT users.id AS id FROM users INNER JOIN orders ON orders.user_id = users.id WHERE orders.status = 'active') AS matched WHERE matched.id = users.id)" }

      it "formats the NOT EXISTS subquery" do
        expect(output).to include("where   not exists (")
      end

      it "formats the inner SELECT" do
        expect(output).to include("select  1")
      end

      it "preserves the derived table structure" do
        expect(output).to include(") matched")
      end

      it "formats the derived table content" do
        expect(output).to include("select  distinct")
      end

      it "formats the inner WHERE condition" do
        expect(output).to include("where   matched.id =")
      end
    end

    context "with a regular table joined to a derived table" do
      let(:value) { "SELECT users.name, stats.order_count FROM users INNER JOIN (SELECT user_id, count(*) AS order_count FROM orders GROUP BY user_id) AS stats ON stats.user_id = users.id" }

      it "formats the outer table normally" do
        expect(output).to include("from    Users u")
      end

      it "formats the derived table join as a subquery" do
        expect(output).to include("inner join (")
        expect(output).to include("select  user_id")
        expect(output).to include(") stats on")
      end
    end

    ############################################################################
    ## CTE Integration
    ############################################################################

    context "with a single CTE" do
      let(:value) { "WITH active_users AS (SELECT id, name FROM users WHERE active = true) SELECT * FROM active_users" }

      it "formats the CTE and main query" do
        expect(output).to match_formatted_text(<<~SQL)
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
                  inner join Recent_Orders ro on ro.user_id = au.id
        SQL
      end
    end

    context "with a CTE containing joins and conditions" do
      let(:value) { "WITH order_details AS (SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE orders.total > 100) SELECT * FROM order_details" }

      it "formats the CTE body with join and alias handling" do
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to include(<<~SQL.chomp)
          select  *
          from    Numbers n
        SQL
      end
    end

    context "with a recursive CTE with a SEARCH clause" do
      let(:value) { "WITH RECURSIVE cte AS (SELECT id FROM nodes) SEARCH DEPTH FIRST BY id SET order_col SELECT * FROM cte" }

      it "preserves the SEARCH clause while formatting the CTE body" do
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to match_formatted_text(<<~SQL)
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
        expect(output).to include_formatted_text(<<~SQL.chomp)
          ····select  distinct
          ····        c.id
        SQL
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
        expect(output).to match_formatted_text(<<~SQL)
          create temp table if not exists Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    ############################################################################
    ## Compound Query (Set Operator) Integration
    ############################################################################

    context "with a UNION between two SELECTs" do
      let(:value) { "SELECT id FROM users UNION SELECT id FROM admins" }

      it "formats each segment and places UNION on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union

          select  id
          from    Admins a
        SQL
      end
    end

    context "with a UNION ALL between two SELECTs" do
      let(:value) { "SELECT id, name FROM users UNION ALL SELECT id, name FROM admins" }

      it "formats each segment with UNION ALL on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          union all

          select  id,
                  name

          from    Admins a
        SQL
      end
    end

    context "with INTERSECT between two SELECTs" do
      let(:value) { "SELECT id FROM users INTERSECT SELECT id FROM departments" }

      it "formats with INTERSECT on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          intersect

          select  id
          from    Departments d
        SQL
      end
    end

    context "with EXCEPT between two SELECTs" do
      let(:value) { "SELECT id FROM users EXCEPT SELECT id FROM departments" }

      it "formats with EXCEPT on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          except

          select  id
          from    Departments d
        SQL
      end
    end

    context "with INTERSECT ALL between two SELECTs" do
      let(:value) { "SELECT id FROM users INTERSECT ALL SELECT id FROM departments" }

      it "formats with INTERSECT ALL on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          intersect all

          select  id
          from    Departments d
        SQL
      end
    end

    context "with EXCEPT ALL between two SELECTs" do
      let(:value) { "SELECT id FROM users EXCEPT ALL SELECT id FROM departments" }

      it "formats with EXCEPT ALL on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          except all

          select  id
          from    Departments d
        SQL
      end
    end

    context "with three segments and mixed operators" do
      let(:value) { "SELECT id FROM users UNION ALL SELECT id FROM admins UNION SELECT id FROM managers" }

      it "formats all three segments with their operators" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union all

          select  id
          from    Admins a

          union

          select  id
          from    Managers m
        SQL
      end
    end

    context "with a compound query and trailing ORDER BY and LIMIT" do
      let(:value) { "SELECT id FROM users UNION ALL SELECT id FROM admins ORDER BY id LIMIT 10" }

      it "formats trailing clauses after the last segment" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union all

          select  id
          from    Admins a

          order by id
          limit 10
        SQL
      end
    end

    context "with a compound query inside a CTE body" do
      let(:value) { "WITH combined AS (SELECT id FROM users UNION ALL SELECT id FROM admins) SELECT * FROM combined" }

      it "formats the CTE body as a compound query" do
        expect(output).to match_formatted_text(<<~SQL)
          with    combined as (
                      select  id
                      from    Users u

                      union all

                      select  id
                      from    Admins a
                  )

          select  *
          from    Combined c
        SQL
      end
    end

    context "with a set operator keyword inside a string literal" do
      let(:value) { "SELECT id FROM users WHERE name = 'union all'" }

      it "does not split on the string literal" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   name = 'union all'
        SQL
      end
    end

    context "with a set operator keyword inside a parenthesized subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT id FROM a UNION ALL SELECT id FROM b)" }

      it "formats the subquery with its own compound query" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  id
                      from    A a

                      union all

                      select  id
                      from    B b
                  )
        SQL
      end
    end

    context "with compound query segments that have JOINs and WHERE conditions" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id WHERE users.active = true UNION ALL SELECT admins.id, requests.total FROM admins INNER JOIN requests ON requests.admin_id = admins.id WHERE admins.role = 'super'" }

      it "formats each segment independently with its own aliases" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id

          where   u.active = true

          union all

          select  a.id,
                  r.total

          from    Admins a
                  inner join Requests r on r.admin_id = a.id

          where   a.role = 'super'
        SQL
      end
    end

    context "with a CTE whose main query is a compound query" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT id FROM active UNION ALL SELECT id FROM admins" }

      it "formats the CTE and then the compound main query" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active as (
                      select  id
                      from    Users u
                      where   active = true
                  )

          select  id
          from    Active a

          union all

          select  id
          from    Admins a
        SQL
      end
    end

    ############################################################################
    ## INSERT Integration
    ############################################################################

    context "with a simple INSERT INTO...VALUES" do
      let(:value) { "INSERT INTO users (id, name, email) VALUES (1, 'Alice', 'alice@example.com')" }

      it "formats the INSERT with column list and values" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name,
              email
          )
          values  (1, 'Alice', 'alice@example.com')
        SQL
      end
    end

    context "with a multi-row INSERT" do
      let(:value) { "INSERT INTO users (id, name) VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Carol')" }

      it "formats each value row on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice'),
                  (2, 'Bob'),
                  (3, 'Carol')
        SQL
      end
    end

    context "with INSERT...SELECT" do
      let(:value) { "INSERT INTO users (id, name) SELECT id, name FROM temp_users WHERE active = true" }

      it "formats the INSERT and delegates the SELECT" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name
          )

          select  id,
                  name

          from    Temp_Users tu

          where   active = true
        SQL
      end
    end

    context "with INSERT...SELECT with JOINs" do
      let(:value) { "INSERT INTO archive_orders (id, total) SELECT orders.id, orders.total FROM orders INNER JOIN users ON users.id = orders.user_id WHERE orders.status = 'closed'" }

      it "formats the INSERT and delegates the SELECT with JOINs" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Archive_Orders (
              id,
              total
          )

          select  o.id,
                  o.total

          from    Orders o
                  inner join Users u on u.id = o.user_id

          where   o.status = 'closed'
        SQL
      end
    end

    context "with INSERT without column list" do
      let(:value) { "INSERT INTO users VALUES (1, 'Alice', 'alice@example.com')" }

      it "formats without a column list" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users
          values  (1, 'Alice', 'alice@example.com')
        SQL
      end
    end

    context "with INSERT...RETURNING" do
      let(:value) { "INSERT INTO users (id, name) VALUES (1, 'Alice') RETURNING id, name" }

      it "formats with the RETURNING clause" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice')
          returning id, name
        SQL
      end
    end

    context "with INSERT...ON CONFLICT DO NOTHING" do
      let(:value) { "INSERT INTO users (id, name) VALUES (1, 'Alice') ON CONFLICT (id) DO NOTHING" }

      it "formats with the ON CONFLICT clause" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice')
          on conflict (id) do nothing
        SQL
      end
    end

    context "with INSERT...ON CONFLICT DO UPDATE SET...RETURNING" do
      let(:value) { "INSERT INTO users (id, name) VALUES (1, 'Alice') ON CONFLICT (id) DO UPDATE SET name = excluded.name RETURNING id" }

      it "formats with ON CONFLICT, SET, and RETURNING" do
        expect(output).to match_formatted_text(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice')
          on conflict (id) do update set name = excluded.name
          returning id
        SQL
      end
    end

    ############################################################################
    ## UPDATE Integration
    ############################################################################

    context "with a simple UPDATE...SET...WHERE" do
      let(:value) { "UPDATE users SET name = 'Alice', email = 'alice@example.com' WHERE id = 1" }

      it "formats with keyword alignment" do
        expect(output).to match_formatted_text(<<~SQL)
          update  Users
          set     name = 'Alice',
                  email = 'alice@example.com'
          where   id = 1
        SQL
      end
    end

    context "with UPDATE...SET...FROM...WHERE" do
      let(:value) { "UPDATE users SET name = accounts.name FROM accounts WHERE users.account_id = accounts.id" }

      it "formats with FROM clause" do
        expect(output).to match_formatted_text(<<~SQL)
          update  Users
          set     name = accounts.name
          from    accounts
          where   users.account_id = accounts.id
        SQL
      end
    end

    context "with UPDATE...RETURNING" do
      let(:value) { "UPDATE users SET active = true WHERE id = 1 RETURNING id, active" }

      it "formats with RETURNING clause" do
        expect(output).to match_formatted_text(<<~SQL)
          update  Users
          set     active = true
          where   id = 1
          returning id, active
        SQL
      end
    end

    context "with UPDATE with multiple WHERE conditions" do
      let(:value) { "UPDATE users SET active = false WHERE role = 'guest' AND last_login < '2024-01-01' AND verified = false" }

      it "formats WHERE conditions on separate lines" do
        expect(output).to match_formatted_text(<<~SQL)
          update  Users
          set     active = false
          where   role = 'guest'
                  and last_login < '2024-01-01'
                  and verified = false
        SQL
      end
    end

    ############################################################################
    ## DELETE Integration
    ############################################################################

    context "with a simple DELETE FROM...WHERE" do
      let(:value) { "DELETE FROM users WHERE status = 'inactive'" }

      it "formats with keyword alignment" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          where   status = 'inactive'
        SQL
      end
    end

    context "with DELETE FROM without WHERE" do
      let(:value) { "DELETE FROM temp_users" }

      it "formats without WHERE" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Temp_Users
        SQL
      end
    end

    context "with DELETE...USING...WHERE" do
      let(:value) { "DELETE FROM users USING accounts WHERE users.account_id = accounts.id AND accounts.expired = true" }

      it "formats with USING and WHERE clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          using   accounts
          where   users.account_id = accounts.id
                  and accounts.expired = true
        SQL
      end
    end

    context "with DELETE...RETURNING" do
      let(:value) { "DELETE FROM users WHERE id = 1 RETURNING id, name" }

      it "formats with RETURNING clause" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          where   id = 1
          returning id, name
        SQL
      end
    end

    ############################################################################
    ## DML Regression Safety
    ############################################################################

    context "with a malformed INSERT (no INTO)" do
      let(:value) { "INSERT something somewhere" }

      it "falls through to normalize-only path" do
        expect(output).to match_formatted_text(<<~SQL)
          insert something somewhere
        SQL
      end
    end

    context "with a malformed DELETE (no FROM)" do
      let(:value) { "DELETE something WHERE id = 1" }

      it "falls through to normalize-only path" do
        expect(output).to match_formatted_text(<<~SQL)
          delete something where id = 1
        SQL
      end
    end

    context "with existing SELECT queries after DML additions" do
      let(:value) { "SELECT id, name FROM users WHERE active = true ORDER BY name LIMIT 10" }

      it "still formats SELECT queries correctly" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true

          order by name

          limit 10
        SQL
      end
    end

    ############################################################################
    ## CASE Expressions
    ############################################################################

    context "with a CASE expression in a SELECT column" do
      let(:value) { "SELECT id, CASE WHEN u.status = 'active' THEN 'Active' WHEN u.status = 'pending' THEN 'Pending' ELSE 'Unknown' END AS status_label, name FROM users" }

      it "formats the CASE expression with multiline indentation" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  case
                      when u.status = 'active' then 'Active'
                      when u.status = 'pending' then 'Pending'
                      else 'Unknown'
                  end as status_label,
                  name

          from    Users u
        SQL
      end
    end

    context "with a CASE expression in a WHERE condition" do
      let(:value) { "SELECT id FROM users WHERE CASE WHEN role = 'admin' THEN 1 ELSE 0 END = 1" }

      it "formats the CASE expression in the WHERE clause" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   case
                      when role = 'admin' then 1
                      else 0
                  end = 1
        SQL
      end
    end

    context "with a CASE expression in a WHERE condition with multiple conditions" do
      let(:value) { "SELECT id FROM users WHERE active = true AND CASE WHEN role = 'admin' THEN true ELSE false END = true" }

      it "formats the CASE within the multi-condition WHERE" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and case
                      when role = 'admin' then true
                      else false
                  end = true
        SQL
      end
    end

    context "with multiple CASE expressions in the same SELECT" do
      let(:value) { "SELECT CASE WHEN a = 1 THEN 'x' ELSE 'y' END AS col1, CASE WHEN b = 2 THEN 'p' ELSE 'q' END AS col2 FROM users" }

      it "formats both CASE expressions" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case
                      when a = 1 then 'x'
                      else 'y'
                  end as col1,
                  case
                      when b = 2 then 'p'
                      else 'q'
                  end as col2

          from    Users u
        SQL
      end
    end

    context "with a CASE expression with alias" do
      let(:value) { "SELECT CASE WHEN x > 0 THEN 'positive' ELSE 'negative' END AS sign FROM users" }

      it "preserves the alias after END" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case
                      when x > 0 then 'positive'
                      else 'negative'
                  end as sign

          from    Users u
        SQL
      end
    end

    context "with a simple CASE expression (CASE expr WHEN value)" do
      let(:value) { "SELECT CASE u.role WHEN 'admin' THEN 'Administrator' WHEN 'user' THEN 'Standard User' ELSE 'Guest' END AS role_label FROM users" }

      it "formats the simple CASE with operand on the CASE line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case u.role
                      when 'admin' then 'Administrator'
                      when 'user' then 'Standard User'
                      else 'Guest'
                  end as role_label

          from    Users u
        SQL
      end
    end

    context "with a nested CASE expression" do
      let(:value) { "SELECT CASE WHEN x = 1 THEN CASE WHEN y = 1 THEN 'a' ELSE 'b' END WHEN x = 2 THEN 'c' END AS result FROM users" }

      it "formats the outer and inner CASE expressions" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case
                      when x = 1 then case
                          when y = 1 then 'a'
                          else 'b'
                      end
                      when x = 2 then 'c'
                  end as result

          from    Users u
        SQL
      end
    end

    context "with a CASE expression inside a function call in SELECT" do
      let(:value) { "SELECT COALESCE(CASE WHEN x > 0 THEN x ELSE NULL END, 0) AS safe_x FROM users" }

      it "preserves the CASE inside the function call" do
        expect(output).to match_formatted_text(<<~SQL)
          select  coalesce(case when x > 0 then x else null end, 0) as safe_x
          from    Users u
        SQL
      end
    end

    context "with a CASE expression in UPDATE SET" do
      let(:value) { "UPDATE users SET status = CASE WHEN active = true THEN 'enabled' ELSE 'disabled' END WHERE id = 1" }

      it "formats the CASE in the SET assignment" do
        expect(output).to match_formatted_text(<<~SQL)
          update  Users
          set     status = case
                      when active = true then 'enabled'
                      else 'disabled'
                  end
          where   id = 1
        SQL
      end
    end

    context "with a CASE expression without ELSE" do
      let(:value) { "SELECT CASE WHEN active = true THEN 'yes' END AS status FROM users" }

      it "formats without an ELSE line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case
                      when active = true then 'yes'
                  end as status

          from    Users u
        SQL
      end
    end

    context "with a query containing no CASE expressions" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "formats without any CASE-related changes" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true
        SQL
      end
    end

    context "with case_-prefixed and end_-prefixed column names" do
      let(:value) { "SELECT case_id, end_date FROM users WHERE case_id = 1 AND end_date > '2026-01-01'" }

      it "does not misidentify case_id or end_date as CASE/END keywords" do
        expect(output).to match_formatted_text(<<~SQL)
          select  case_id,
                  end_date

          from    Users u

          where   case_id = 1
                  and end_date > '2026-01-01'
        SQL
      end
    end
  end
end
