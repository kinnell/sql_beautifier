# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::From do
  describe ".call" do
    let(:table_registry) { SqlBeautifier::TableRegistry.new(value) }
    let(:output) { described_class.call(value, table_registry: table_registry) }

    context "with a single table" do
      let(:value) { "users" }

      it "formats with PascalCase and alias" do
        expect(output).to eq("from    Users u")
      end
    end

    context "with an underscore-separated table" do
      let(:value) { "active_storage_blobs" }

      it "formats with PascalCase and initials alias" do
        expect(output).to eq("from    Active_Storage_Blobs asb")
      end
    end

    context "with extra whitespace" do
      let(:value) { "  users  " }

      it "strips whitespace" do
        expect(output).to eq("from    Users u")
      end
    end

    context "with an explicit alias" do
      let(:value) { "users usr" }

      it "preserves the explicit alias" do
        expect(output).to eq("from    Users usr")
      end
    end

    ############################################################################
    ## Join Types
    ############################################################################

    context "with an inner join" do
      let(:value) { "users inner join orders on orders.user_id = users.id" }

      it "formats the join on a continuation line" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  inner join Orders o on orders.user_id = users.id
        SQL
      end
    end

    context "with a left join" do
      let(:value) { "users left join profiles on profiles.user_id = users.id" }

      it "formats the left join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  left join Profiles p on profiles.user_id = users.id
        SQL
      end
    end

    context "with a right join" do
      let(:value) { "users right join profiles on profiles.user_id = users.id" }

      it "formats the right join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  right join Profiles p on profiles.user_id = users.id
        SQL
      end
    end

    context "with a left outer join" do
      let(:value) { "users left outer join addresses on addresses.user_id = users.id" }

      it "formats the left outer join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  left outer join Addresses a on addresses.user_id = users.id
        SQL
      end
    end

    context "with a right outer join" do
      let(:value) { "users right outer join archived_users on archived_users.user_id = users.id" }

      it "formats the right outer join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  right outer join Archived_Users au on archived_users.user_id = users.id
        SQL
      end
    end

    context "with a full outer join" do
      let(:value) { "users full outer join legacy_users on legacy_users.email = users.email" }

      it "formats the full outer join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  full outer join Legacy_Users lu on legacy_users.email = users.email
        SQL
      end
    end

    context "with a full join" do
      let(:value) { "users full join profiles on profiles.user_id = users.id" }

      it "formats the full join" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  full join Profiles p on profiles.user_id = users.id
        SQL
      end
    end

    context "with a cross join" do
      let(:value) { "users cross join roles" }

      it "formats the cross join without an ON clause" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  cross join Roles r
        SQL
      end
    end

    ############################################################################
    ## Multiple Joins
    ############################################################################

    context "with multiple joins of the same type" do
      let(:value) { "users inner join orders on orders.user_id = users.id inner join products on products.id = orders.product_id" }

      it "formats each join on its own continuation line" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  inner join Orders o on orders.user_id = users.id
                  inner join Products p on products.id = orders.product_id
        SQL
      end
    end

    context "with mixed join types" do
      let(:value) { "users inner join orders on orders.user_id = users.id left join payments on payments.order_id = orders.id" }

      it "formats each join type on its own continuation line" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  inner join Orders o on orders.user_id = users.id
                  left join Payments p on payments.order_id = orders.id
        SQL
      end
    end

    ############################################################################
    ## Multi-Condition Joins
    ############################################################################

    context "with a multi-condition join" do
      let(:value) { "persons inner join person_event_invitations on person_event_invitations.person_id = persons.id and person_event_invitations.event_id = 42" }

      it "formats additional conditions on indented lines" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Persons p
                  inner join Person_Event_Invitations pei on person_event_invitations.person_id = persons.id
                      and person_event_invitations.event_id = 42
        SQL
      end
    end

    context "with three ON conditions" do
      let(:value) { "users inner join orders on orders.user_id = users.id and orders.status = 'active' and orders.total > 0" }

      it "formats each additional condition on its own indented line" do
        expect(output).to match_formatted_text(<<~SQL)
          from    Users u
                  inner join Orders o on orders.user_id = users.id
                      and orders.status = 'active'
                      and orders.total > 0
        SQL
      end
    end
  end
end
