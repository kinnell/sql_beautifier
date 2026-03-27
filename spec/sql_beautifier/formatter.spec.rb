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
        expect(output).to eq("select  id\n\nfrom    Users u\n")
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

      it "separates limit with a blank line" do
        expect(output).to include("Users u\n\nlimit")
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

      it "keeps the subquery intact in the where clause" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   id in (select user_id from orders)
        SQL
      end
    end

    context "when the value has a subquery in the select clause" do
      let(:value) { "SELECT id, (SELECT count(*) FROM orders WHERE orders.user_id = users.id) FROM users" }

      it "keeps the subquery intact in the select clause" do
        expect(output).to include("select  id,")
        expect(output).to include("(select count(*) from orders where orders.user_id = u.id)")
        expect(output).to include("from    Users u")
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

      it "keeps inline groups and formats conditions" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator')
                  and verified = true
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
  end
end
