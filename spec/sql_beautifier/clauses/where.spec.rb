# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Where do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a simple condition" do
      let(:value) { "active = true" }

      it "formats with keyword prefix" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   active = true
        SQL
      end
    end

    context "with AND conditions" do
      let(:value) { "active = true and name = 'Alice'" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   active = true
                  and name = 'Alice'
        SQL
      end
    end

    context "with three AND conditions" do
      let(:value) { "a = 1 and b = 2 and c = 3 and d = 4" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   a = 1
                  and b = 2
                  and c = 3
                  and d = 4
        SQL
      end
    end

    context "with OR conditions" do
      let(:value) { "status = 'active' or status = 'pending'" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   status = 'active'
                  or status = 'pending'
        SQL
      end
    end

    context "with mixed AND/OR conditions" do
      let(:value) { "active = true and name = 'Alice' or status = 'pending'" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   active = true
                  and name = 'Alice'
                  or status = 'pending'
        SQL
      end
    end

    context "with a parenthesized group" do
      let(:value) { "active = true and (role = 'admin' or role = 'moderator')" }

      it "expands the group to multiple lines" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   active = true
                  and (
                      role = 'admin'
                      or role = 'moderator'
                  )
        SQL
      end
    end

    context "with multiple parenthesized groups" do
      let(:value) { "active = true and (role = 'admin' or role = 'mod') and (status = 'verified' or status = 'pending')" }

      it "expands each group to multiple lines" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   active = true
                  and (
                      role = 'admin'
                      or role = 'mod'
                  )
                  and (
                      status = 'verified'
                      or status = 'pending'
                  )
        SQL
      end
    end

    context "with a function call in a condition" do
      let(:value) { "lower(name) = 'alice' and active = true" }

      it "preserves function parentheses" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   lower(name) = 'alice'
                  and active = true
        SQL
      end
    end

    context "with IS NULL condition" do
      let(:value) { "name is not null and deleted_at is null" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   name is not null
                  and deleted_at is null
        SQL
      end
    end

    context "with a subquery condition" do
      let(:value) { "id in (select user_id from orders)" }

      it "keeps the subquery intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   id in (select user_id from orders)
        SQL
      end
    end

    context "with an IN list alongside another condition" do
      let(:value) { "status in ('active', 'pending') and role = 'admin'" }

      it "keeps the IN list intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   status in ('active', 'pending')
                  and role = 'admin'
        SQL
      end
    end

    context "with a BETWEEN condition" do
      let(:value) { "created_at between '2024-01-01' and '2024-12-31'" }

      it "keeps the BETWEEN...AND expression intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   created_at between '2024-01-01' and '2024-12-31'
        SQL
      end
    end

    context "with a BETWEEN condition alongside another condition" do
      let(:value) { "created_at between '2024-01-01' and '2024-12-31' and active = true" }

      it "keeps the BETWEEN intact and splits on the logical AND" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   created_at between '2024-01-01' and '2024-12-31'
                  and active = true
        SQL
      end
    end

    context "with NOT BETWEEN" do
      let(:value) { "age not between 18 and 65 and active = true" }

      it "keeps the NOT BETWEEN...AND expression intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   age not between 18 and 65
                  and active = true
        SQL
      end
    end

    context "with multiple BETWEEN conditions" do
      let(:value) { "created_at between '2024-01-01' and '2024-06-30' and updated_at between '2024-03-01' and '2024-06-30'" }

      it "keeps each BETWEEN intact and splits on the logical AND" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   created_at between '2024-01-01' and '2024-06-30'
                  and updated_at between '2024-03-01' and '2024-06-30'
        SQL
      end
    end

    context "with a NOT condition" do
      let(:value) { "not active = true and role = 'admin'" }

      it "formats with the NOT prefix" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   not active = true
                  and role = 'admin'
        SQL
      end
    end

    context "with a LIKE condition" do
      let(:value) { "name like '%alice%' and active = true" }

      it "keeps the LIKE expression intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   name like '%alice%'
                  and active = true
        SQL
      end
    end

    context "with an EXISTS subquery" do
      let(:value) { "exists (select 1 from orders where orders.user_id = users.id)" }

      it "keeps the subquery intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   exists (select 1 from orders where orders.user_id = users.id)
        SQL
      end
    end

    context "with NOT IN" do
      let(:value) { "status not in ('deleted', 'banned') and active = true" }

      it "keeps the NOT IN expression intact" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   status not in ('deleted', 'banned')
                  and active = true
        SQL
      end
    end

    context "with IS NOT NULL alongside other conditions" do
      let(:value) { "email is not null and verified_at is not null and active = true" }

      it "formats each condition on its own line" do
        expect(output).to match_formatted_text(<<~SQL.chomp)
          where   email is not null
                  and verified_at is not null
                  and active = true
        SQL
      end
    end
  end
end
