# frozen_string_literal: true

RSpec.describe SqlBeautifier::DeleteQuery do
  describe ".parse" do
    context "with a non-DELETE statement" do
      let(:result) { described_class.parse("select id from users") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with DELETE missing FROM" do
      let(:result) { described_class.parse("delete users where id = 1") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with DELETE FROM ONLY" do
      let(:result) { described_class.parse("delete from only users where id = 1") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with unrecognized text after table" do
      let(:result) { described_class.parse("delete from users u garbage") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with unrecognized text before a valid clause" do
      let(:result) { described_class.parse("delete from users u garbage where id = 1") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a simple DELETE FROM...WHERE" do
      let(:result) { described_class.parse("delete from users where id = 1") }

      it "returns a DeleteQuery instance" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "parses the where clause" do
        expect(result.where_clause).to eq("id = 1")
      end
    end

    context "with DELETE FROM without WHERE" do
      let(:result) { described_class.parse("delete from users") }

      it "returns a DeleteQuery instance" do
        expect(result).to be_a(described_class)
      end

      it "has no where clause" do
        expect(result.where_clause).to be_nil
      end
    end

    context "with a table alias" do
      let(:result) { described_class.parse("delete from users u where u.id = 1") }

      it "parses the table alias" do
        expect(result.table_alias).to eq("u")
      end

      it "parses the where clause" do
        expect(result.where_clause).to eq("u.id = 1")
      end
    end

    context "with a table alias using AS" do
      let(:result) { described_class.parse("delete from users as u where u.id = 1") }

      it "parses the table alias" do
        expect(result.table_alias).to eq("u")
      end
    end

    context "with a USING clause" do
      let(:result) { described_class.parse("delete from users using accounts where users.account_id = accounts.id") }

      it "parses the using clause" do
        expect(result.using_clause).to eq("accounts")
      end

      it "parses the where clause" do
        expect(result.where_clause).to eq("users.account_id = accounts.id")
      end
    end

    context "with a RETURNING clause" do
      let(:result) { described_class.parse("delete from users where id = 1 returning id") }

      it "parses the returning clause" do
        expect(result.returning_clause).to eq("id")
      end
    end

    context "with depth parameter" do
      let(:result) { described_class.parse("delete from users where id = 1", depth: 4) }

      it "preserves the depth" do
        expect(result.depth).to eq(4)
      end
    end
  end

  describe "#render" do
    context "with a simple DELETE FROM...WHERE" do
      let(:output) { described_class.parse("delete from users where status = 'inactive'").render }

      it "formats with keyword alignment" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          where   status = 'inactive'
        SQL
      end
    end

    context "with DELETE FROM without WHERE" do
      let(:output) { described_class.parse("delete from users").render }

      it "formats without where clause" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
        SQL
      end
    end

    context "with USING clause" do
      let(:output) { described_class.parse("delete from users using accounts where users.account_id = accounts.id and accounts.expired = true").render }

      it "formats with using and where clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          using   accounts
          where   users.account_id = accounts.id
                  and accounts.expired = true
        SQL
      end
    end

    context "with RETURNING clause" do
      let(:output) { described_class.parse("delete from users where id = 1 returning id, name").render }

      it "formats with returning clause" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          where   id = 1
          returning id, name
        SQL
      end
    end

    context "with a table alias" do
      let(:output) { described_class.parse("delete from users u where u.id = 1").render }

      it "includes the alias in the from clause" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users u
          where   u.id = 1
        SQL
      end
    end

    context "with a table alias using AS" do
      let(:output) { described_class.parse("delete from users as u where u.id = 1").render }

      it "includes the alias in the from clause" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users u
          where   u.id = 1
        SQL
      end
    end

    context "with multiple WHERE conditions" do
      let(:output) { described_class.parse("delete from users where status = 'inactive' and last_login < '2024-01-01' and role = 'guest'").render }

      it "formats WHERE conditions on separate lines" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          where   status = 'inactive'
                  and last_login < '2024-01-01'
                  and role = 'guest'
        SQL
      end
    end

    context "with USING, WHERE, and RETURNING" do
      let(:output) { described_class.parse("delete from users using accounts where users.account_id = accounts.id returning users.id").render }

      it "formats all clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          delete
          from    Users
          using   accounts
          where   users.account_id = accounts.id
          returning users.id
        SQL
      end
    end
  end
end
