# frozen_string_literal: true

RSpec.describe "README examples" do
  let(:output) { SqlBeautifier.call(value) }

  context "basic formatting" do
    let(:value) { "SELECT id, name, email FROM users WHERE active = true ORDER BY name" }

    it "formats with spacious spacing and trailing semicolon" do
      expect(output).to eq(<<~SQL)
        select  id,
                name,
                email

        from    Users u

        where   active = true

        order by name;
      SQL
    end
  end

  context "table aliasing with reference replacement" do
    let(:value) { "SELECT users.id, users.name FROM users WHERE users.active = true" }

    it "aliases the table and replaces all table references" do
      expect(output).to eq(<<~SQL)
        select  u.id,
                u.name

        from    Users u

        where   u.active = true;
      SQL
    end
  end

  context "multi-table JOINs" do
    let(:value) { "SELECT users.id, orders.total, products.name FROM users INNER JOIN orders ON orders.user_id = users.id INNER JOIN products ON products.id = orders.product_id WHERE users.active = true AND orders.total > 100 ORDER BY orders.total DESC" }

    it "formats each join with aliases and reference replacement" do
      expect(output).to eq(<<~SQL)
        select  u.id,
                o.total,
                p.name

        from    Users u
                inner join Orders o on o.user_id = u.id
                inner join Products p on p.id = o.product_id

        where   u.active = true
                and o.total > 100

        order by o.total desc;
      SQL
    end
  end

  context "DISTINCT with multiple columns" do
    let(:value) { "SELECT DISTINCT id, name, email FROM users" }

    it "places distinct on the select line with columns on continuation lines" do
      expect(output).to eq(<<~SQL)
        select  distinct
                id,
                name,
                email

        from    Users u;
      SQL
    end
  end

  context "DISTINCT ON" do
    let(:value) { "SELECT DISTINCT ON (user_id) id, name FROM events" }

    it "preserves the distinct on expression" do
      expect(output).to eq(<<~SQL)
        select  distinct on (user_id)
                id,
                name

        from    Events e;
      SQL
    end
  end

  context "WHERE with three AND conditions" do
    let(:value) { "SELECT * FROM users WHERE active = true AND role = 'admin' AND created_at > '2024-01-01'" }

    it "formats each condition on its own line" do
      expect(output).to eq(<<~SQL)
        select  *

        from    Users u

        where   active = true
                and role = 'admin'
                and created_at > '2024-01-01';
      SQL
    end
  end

  context "WHERE with parenthesized OR group" do
    let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

    it "expands the parenthesized group" do
      expect(output).to eq(<<~SQL)
        select  *

        from    Users u

        where   active = true
                and (
                    role = 'admin'
                    or role = 'moderator'
                );
      SQL
    end
  end

  context "GROUP BY and HAVING" do
    let(:value) { "SELECT status, count(*) FROM users GROUP BY status HAVING count(*) > 5" }

    it "formats group by and having clauses" do
      expect(output).to eq(<<~SQL)
        select  status,
                count(*)

        from    Users u

        group by status

        having  count(*) > 5;
      SQL
    end
  end

  context "LIMIT with compact spacing" do
    let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25" }

    it "formats with compact spacing" do
      expect(output).to eq(<<~SQL)
        select  id
        from    Users u
        order by created_at desc
        limit 25;
      SQL
    end
  end

  context "string literals with escaped quotes" do
    let(:value) { "SELECT * FROM users WHERE name = 'O''Brien' AND status = 'Active'" }

    it "preserves case and escaped quotes inside string literals" do
      expect(output).to eq(<<~SQL)
        select  *

        from    Users u

        where   name = 'O''Brien'
                and status = 'Active';
      SQL
    end
  end

  context "double-quoted identifiers" do
    let(:value) { 'SELECT "User_Id", "Full_Name" FROM "Users"' }

    it "lowercases and unquotes safe identifiers" do
      expect(output).to eq(<<~SQL)
        select  user_id,
                full_name

        from    Users u;
      SQL
    end
  end

  context "subquery in WHERE" do
    let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE total > 100)" }

    it "formats the subquery with indentation" do
      expect(output).to eq(<<~SQL)
        select  id
        from    Users u
        where   id in (
                    select  user_id
                    from    Orders o
                    where   total > 100
                );
      SQL
    end
  end

  context "trailing semicolons" do
    let(:value) { "SELECT id FROM users WHERE active = true" }

    it "appends a trailing semicolon by default" do
      expect(output).to eq(<<~SQL)
        select  id
        from    Users u
        where   active = true;
      SQL
    end
  end

  context "multiple semicolon-separated statements" do
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

  context "concatenated statements without semicolons" do
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

  context "comments" do
    let(:value) { "-- Base Query\nSELECT id /* primary key */ FROM users WHERE active = true" }

    it "preserves line and block comments with compact spacing" do
      expect(output).to eq(<<~SQL)
        -- Base Query
        select  id /* primary key */
        from    Users u
        where   active = true;
      SQL
    end
  end
end
