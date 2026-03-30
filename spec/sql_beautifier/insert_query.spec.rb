# frozen_string_literal: true

RSpec.describe SqlBeautifier::InsertQuery do
  describe ".parse" do
    context "with a non-INSERT statement" do
      let(:result) { described_class.parse("select id from users") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with INSERT missing INTO" do
      let(:result) { described_class.parse("insert users (id) values (1)") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with VALUES keyword but no value tuples" do
      let(:result) { described_class.parse("insert into users (id) values") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with unrecognized trailing text after VALUES tuples" do
      let(:result) { described_class.parse("insert into users (id) values (1) foo") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a trailing comma after VALUES tuples" do
      let(:result) { described_class.parse("insert into users (id) values (1),") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a simple INSERT...VALUES" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice')") }

      it "returns an InsertQuery instance" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "parses the column list" do
        expect(result.column_list).to eq("id, name")
      end

      it "parses the values rows" do
        expect(result.values_rows).to eq(["(1, 'Alice')"])
      end
    end

    context "with multi-row VALUES" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice'), (2, 'Bob'), (3, 'Carol')") }

      it "parses all value rows" do
        expect(result.values_rows.length).to eq(3)
      end

      it "parses the first row" do
        expect(result.values_rows[0]).to eq("(1, 'Alice')")
      end

      it "parses the second row" do
        expect(result.values_rows[1]).to eq("(2, 'Bob')")
      end

      it "parses the third row" do
        expect(result.values_rows[2]).to eq("(3, 'Carol')")
      end
    end

    context "with INSERT...SELECT" do
      let(:result) { described_class.parse("insert into users (id, name) select id, name from temp_users") }

      it "parses the select SQL" do
        expect(result.select_sql).to eq("select id, name from temp_users")
      end

      it "has no values rows" do
        expect(result.values_rows).to be_nil
      end
    end

    context "with INSERT without column list" do
      let(:result) { described_class.parse("insert into users values (1, 'Alice')") }

      it "has no column list" do
        expect(result.column_list).to be_nil
      end

      it "parses the values rows" do
        expect(result.values_rows).to eq(["(1, 'Alice')"])
      end
    end

    context "with RETURNING clause" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice') returning id, name") }

      it "parses the returning clause" do
        expect(result.returning_clause).to eq("id, name")
      end
    end

    context "with ON CONFLICT DO NOTHING" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice') on conflict (id) do nothing") }

      it "parses the on conflict clause" do
        expect(result.on_conflict_clause).to eq("on conflict (id) do nothing")
      end
    end

    context "with ON CONFLICT DO UPDATE SET" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice') on conflict (id) do update set name = excluded.name") }

      it "parses the on conflict clause" do
        expect(result.on_conflict_clause).to eq("on conflict (id) do update set name = excluded.name")
      end
    end

    context "with ON CONFLICT and RETURNING" do
      let(:result) { described_class.parse("insert into users (id, name) values (1, 'Alice') on conflict (id) do nothing returning id") }

      it "parses the on conflict clause" do
        expect(result.on_conflict_clause).to eq("on conflict (id) do nothing")
      end

      it "parses the returning clause" do
        expect(result.returning_clause).to eq("id")
      end
    end

    context "with depth parameter" do
      let(:result) { described_class.parse("insert into users (id) values (1)", depth: 8) }

      it "preserves the depth" do
        expect(result.depth).to eq(8)
      end
    end
  end

  describe "#render" do
    context "with a simple INSERT...VALUES" do
      let(:output) { described_class.parse("insert into users (id, name, email) values (1, 'Alice', 'alice@example.com')").render }

      it "formats with keyword alignment" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name,
              email
          )
          values  (1, 'Alice', 'alice@example.com')
        SQL
      end
    end

    context "with multi-row VALUES" do
      let(:output) { described_class.parse("insert into users (id, name, email) values (1, 'Alice', 'alice@example.com'), (2, 'Bob', 'bob@example.com')").render }

      it "formats each row on its own line" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name,
              email
          )
          values  (1, 'Alice', 'alice@example.com'),
                  (2, 'Bob', 'bob@example.com')
        SQL
      end
    end

    context "with INSERT...SELECT" do
      let(:output) { described_class.parse("insert into users (id, name, email) select id, name, email from temp_users").render }

      it "delegates the SELECT to the formatter" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name,
              email
          )

          select  id,
                  name,
                  email

          from    Temp_Users tu
        SQL
      end
    end

    context "with INSERT...SELECT with JOINs and WHERE" do
      let(:output) { described_class.parse("insert into archive_orders (id, total) select orders.id, orders.total from orders inner join users on users.id = orders.user_id where orders.status = 'closed'").render }

      it "formats the SELECT portion with JOINs and WHERE" do
        expect(output).to eq(<<~SQL)
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
      let(:output) { described_class.parse("insert into users values (1, 'Alice')").render }

      it "formats without a column list" do
        expect(output).to eq(<<~SQL)
          insert into Users
          values  (1, 'Alice')
        SQL
      end
    end

    context "with RETURNING clause" do
      let(:output) { described_class.parse("insert into users (id, name) values (1, 'Alice') returning id, name").render }

      it "formats the returning clause" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice')
          returning id, name
        SQL
      end
    end

    context "with ON CONFLICT DO NOTHING" do
      let(:output) { described_class.parse("insert into users (id, name) values (1, 'Alice') on conflict (id) do nothing").render }

      it "formats the on conflict clause" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name
          )
          values  (1, 'Alice')
          on conflict (id) do nothing
        SQL
      end
    end

    context "with ON CONFLICT DO UPDATE SET and RETURNING" do
      let(:output) { described_class.parse("insert into users (id, name, email) values (1, 'Alice', 'alice@example.com') on conflict (id) do update set name = excluded.name, email = excluded.email returning id, name").render }

      it "formats the on conflict and returning clauses" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              name,
              email
          )
          values  (1, 'Alice', 'alice@example.com')
          on conflict (id) do update set name = excluded.name, email = excluded.email
          returning id, name
        SQL
      end
    end

    context "with values containing function calls" do
      let(:output) { described_class.parse("insert into users (id, created_at) values (1, now())").render }

      it "preserves function calls in values" do
        expect(output).to eq(<<~SQL)
          insert into Users (
              id,
              created_at
          )
          values  (1, now())
        SQL
      end
    end
  end
end
