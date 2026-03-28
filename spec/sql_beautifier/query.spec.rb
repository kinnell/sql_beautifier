# frozen_string_literal: true

RSpec.describe SqlBeautifier::Query do
  describe ".parse" do
    let(:query) { described_class.parse(normalized_sql) }

    context "with a simple select-from query" do
      let(:normalized_sql) { "select id from users" }

      it "populates the :select clause" do
        expect(query.clauses[:select]).to eq("id")
      end

      it "populates the :from clause" do
        expect(query.clauses[:from]).to eq("users")
      end

      it "builds a TableRegistry" do
        expect(query.table_registry).to be_a(SqlBeautifier::TableRegistry)
      end

      it "defaults depth to 0" do
        expect(query.depth).to eq(0)
      end
    end

    context "with a depth argument" do
      let(:query) { described_class.parse("select id from users", depth: 2) }

      it "stores the depth" do
        expect(query.depth).to eq(2)
      end
    end

    context "with no from clause" do
      let(:normalized_sql) { "select 1" }

      it "does not build a TableRegistry" do
        expect(query.table_registry).to be_nil
      end
    end

    context "with all clause types" do
      let(:normalized_sql) { "select id from users where active = true group by department having count(*) > 5 order by name limit 10" }

      it "populates all expected clause keys" do
        expect(query.clauses.keys).to contain_exactly(:select, :from, :where, :group_by, :having, :order_by, :limit)
      end
    end
  end

  describe "#compact?" do
    let(:query) { described_class.parse(normalized_sql) }
    let(:compact) { query.compact? }

    context "with a single column, single table, no conditions" do
      let(:normalized_sql) { "select id from users" }

      it "returns true" do
        expect(compact).to be true
      end
    end

    context "with a single column, single table, one condition" do
      let(:normalized_sql) { "select id from users where active = true" }

      it "returns true" do
        expect(compact).to be true
      end
    end

    context "with multiple select columns" do
      let(:normalized_sql) { "select id, name from users" }

      it "returns false" do
        expect(compact).to be false
      end
    end

    context "with a join" do
      let(:normalized_sql) { "select id from users inner join orders on orders.user_id = users.id" }

      it "returns false" do
        expect(compact).to be false
      end
    end

    context "with multiple where conditions" do
      let(:normalized_sql) { "select id from users where active = true and verified = true" }

      it "returns false" do
        expect(compact).to be false
      end
    end

    context "with a group by clause" do
      let(:normalized_sql) { "select count(*) from users group by status" }

      it "returns false" do
        expect(compact).to be false
      end
    end

    context "with a having clause" do
      let(:normalized_sql) { "select count(*) from users group by status having count(*) > 1" }

      it "returns false" do
        expect(compact).to be false
      end
    end

    context "with an order by clause (allowed in compact set)" do
      let(:normalized_sql) { "select id from users order by id" }

      it "returns true" do
        expect(compact).to be true
      end
    end

    context "with a limit clause (allowed in compact set)" do
      let(:normalized_sql) { "select id from users limit 10" }

      it "returns true" do
        expect(compact).to be true
      end
    end
  end

  describe "#render" do
    let(:output) { described_class.parse(normalized_sql, depth: depth).render }
    let(:depth) { 0 }

    context "with a compact query" do
      let(:normalized_sql) { "select id from users" }

      it "uses single-line clause separation" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
        SQL
      end
    end

    context "with a non-compact query" do
      let(:normalized_sql) { "select id, name from users where active = true" }

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

    context "with an empty clauses result" do
      let(:normalized_sql) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a subquery" do
      let(:normalized_sql) { "select id from users where id in (select user_id from orders)" }

      it "formats the subquery with indentation" do
        expect(output).to include("where   id in (")
        expect(output).to include("select  user_id")
      end
    end

    context "with table aliases" do
      let(:normalized_sql) { "select users.id from users inner join orders on orders.user_id = users.id" }

      it "applies alias replacement" do
        expect(output).to include("u.id")
        expect(output).to include("Users u")
        expect(output).to include("Orders o on o.user_id = u.id")
      end
    end

    context "with spacious clause_spacing_mode" do
      let(:normalized_sql) { "select id from users" }

      around do |example|
        SqlBeautifier.call("", clause_spacing_mode: :spacious)
      rescue StandardError
        nil
      ensure
        example.run
      end

      it "uses double-newline separation even for compact queries" do
        output_with_config = SqlBeautifier.call("SELECT id FROM users", clause_spacing_mode: :spacious)

        expect(output_with_config).to include(<<~SQL.chomp)
          id

          from
        SQL
      end
    end

    context "with depth > 0" do
      let(:normalized_sql) { "select id from users" }
      let(:depth) { 1 }

      it "passes depth through for subquery formatting" do
        expect(output).to be_a(String)
        expect(output).to include("select")
      end
    end

    context "with a trailing newline" do
      let(:normalized_sql) { "select id from users" }

      it "ends with a newline" do
        expect(output).to end_with("\n")
      end
    end
  end
end
