# frozen_string_literal: true

RSpec.describe SqlBeautifier::Formatter do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "when the value is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is an empty string" do
      let(:value) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is a whitespace-only string" do
      let(:value) { " " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is a single-line query" do
      let(:value) { "SELECT id FROM users" }

      it "returns the formatted query" do
        expect(output).to eq("select  id\n\nfrom    users\n")
      end
    end

    context "when the value is a simple query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "formats select clause" do
        expect(output).to include("select  id,")
        expect(output).to include("        name")
      end

      it "formats from clause" do
        expect(output).to include("from    users")
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
        expect(output).to include("users\n\nlimit")
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
        expect(output).to include("users\n\nwhere")
      end
    end

    context "when the value has all clauses" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department ORDER BY name LIMIT 25" }

      it "produces the expected full output" do
        expect(output).to eq(<<~SQL)
          select  id

          from    users

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

          from    users

          where   id in (select user_id from orders)
        SQL
      end
    end

    context "when the value has a subquery in the select clause" do
      let(:value) { "SELECT id, (SELECT count(*) FROM orders WHERE orders.user_id = users.id) FROM users" }

      it "keeps the subquery intact in the select clause" do
        expect(output).to include("select  id,")
        expect(output).to include("(select count(*) from orders where orders.user_id = users.id)")
        expect(output).to include("from    users")
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
        expect(output).to include("from    users")
      end
    end
  end
end
