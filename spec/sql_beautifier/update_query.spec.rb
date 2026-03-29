# frozen_string_literal: true

RSpec.describe SqlBeautifier::UpdateQuery do
  describe ".parse" do
    context "with a non-UPDATE statement" do
      let(:result) { described_class.parse("select id from users") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with UPDATE missing SET" do
      let(:result) { described_class.parse("update users where id = 1") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a simple UPDATE...SET...WHERE" do
      let(:result) { described_class.parse("update users set name = 'Alice' where id = 1") }

      it "returns an UpdateQuery instance" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "parses the assignments" do
        expect(result.assignments).to eq("name = 'Alice'")
      end

      it "parses the where clause" do
        expect(result.where_clause).to eq("id = 1")
      end
    end

    context "with multiple assignments" do
      let(:result) { described_class.parse("update users set name = 'Alice', email = 'alice@example.com' where id = 1") }

      it "captures all assignments" do
        expect(result.assignments).to eq("name = 'Alice', email = 'alice@example.com'")
      end
    end

    context "with a FROM clause" do
      let(:result) { described_class.parse("update users set name = accounts.name from accounts where users.account_id = accounts.id") }

      it "parses the from clause" do
        expect(result.from_clause).to eq("accounts")
      end
    end

    context "with a RETURNING clause" do
      let(:result) { described_class.parse("update users set name = 'Alice' where id = 1 returning id, name") }

      it "parses the returning clause" do
        expect(result.returning_clause).to eq("id, name")
      end
    end

    context "with depth parameter" do
      let(:result) { described_class.parse("update users set name = 'Alice' where id = 1", depth: 12) }

      it "preserves the depth" do
        expect(result.depth).to eq(12)
      end
    end

    context "with UPDATE...SET without WHERE" do
      let(:result) { described_class.parse("update users set active = false") }

      it "returns an UpdateQuery instance" do
        expect(result).to be_a(described_class)
      end

      it "has no where clause" do
        expect(result.where_clause).to be_nil
      end
    end
  end

  describe "#render" do
    context "with a simple UPDATE...SET...WHERE" do
      let(:output) { described_class.parse("update users set name = 'Alice' where id = 1").render }

      it "formats with keyword alignment" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     name = 'Alice'
          where   id = 1
        SQL
      end
    end

    context "with multiple assignments" do
      let(:output) { described_class.parse("update users set name = 'Alice', email = 'alice@example.com', active = true where id = 1").render }

      it "formats each assignment on its own line" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     name = 'Alice',
                  email = 'alice@example.com',
                  active = true
          where   id = 1
        SQL
      end
    end

    context "with UPDATE...SET...FROM...WHERE" do
      let(:output) { described_class.parse("update users set name = accounts.name from accounts where users.account_id = accounts.id").render }

      it "formats with FROM clause" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     name = accounts.name
          from    accounts
          where   users.account_id = accounts.id
        SQL
      end
    end

    context "with RETURNING clause" do
      let(:output) { described_class.parse("update users set name = 'Alice' where id = 1 returning id, name").render }

      it "formats with returning clause" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     name = 'Alice'
          where   id = 1
          returning id, name
        SQL
      end
    end

    context "with UPDATE...SET without WHERE" do
      let(:output) { described_class.parse("update users set active = false").render }

      it "formats without where clause" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     active = false
        SQL
      end
    end

    context "with assignments containing function calls" do
      let(:output) { described_class.parse("update users set updated_at = now(), name = upper('alice') where id = 1").render }

      it "preserves function calls in assignments" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     updated_at = now(),
                  name = upper('alice')
          where   id = 1
        SQL
      end
    end

    context "with multiple WHERE conditions" do
      let(:output) { described_class.parse("update users set active = false where role = 'guest' and last_login < '2024-01-01'").render }

      it "formats WHERE conditions on separate lines" do
        expect(output).to eq(<<~SQL)
          update  Users
          set     active = false
          where   role = 'guest'
                  and last_login < '2024-01-01'
        SQL
      end
    end
  end
end
