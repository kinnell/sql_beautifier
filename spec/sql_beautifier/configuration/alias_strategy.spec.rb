# frozen_string_literal: true

RSpec.describe "alias_strategy configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.alias_strategy = config_value
    end
  end

  ############################################################################
  ## alias_strategy: :initials (default)
  ############################################################################

  context "when alias_strategy is :initials (default)" do
    let(:config_value) { :initials }

    context "with a single-word table name" do
      let(:value) { "SELECT users.id FROM users WHERE users.active = true" }

      it "aliases with the first letter and replaces table references" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id
          from    Users u
          where   u.active = true;
        SQL
      end
    end

    context "with an underscore-separated table name" do
      let(:value) { "SELECT active_storage_blobs.id FROM active_storage_blobs" }

      it "aliases with initials of each segment" do
        expect(output).to match_formatted_text(<<~SQL)
          select  asb.id
          from    Active_Storage_Blobs asb;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "aliases each table and replaces all references" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with conflicting initials" do
      let(:value) { "SELECT updates.id, uploads.path FROM updates INNER JOIN uploads ON uploads.update_id = updates.id" }

      it "disambiguates with counters" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u1.id,
                  u2.path

          from    Updates u1
                  inner join Uploads u2 on u2.update_id = u1.id;
        SQL
      end
    end

    context "with explicit aliases in the input" do
      let(:value) { "SELECT users.id FROM users usr WHERE users.active = true" }

      it "preserves explicit aliases" do
        expect(output).to match_formatted_text(<<~SQL)
          select  usr.id
          from    Users usr
          where   usr.active = true;
        SQL
      end
    end
  end

  ############################################################################
  ## alias_strategy: :none
  ############################################################################

  context "when alias_strategy is :none" do
    let(:config_value) { :none }

    context "with a simple query" do
      let(:value) { "SELECT users.id FROM users WHERE users.active = true" }

      it "does not add aliases or replace table references" do
        expect(output).to match_formatted_text(<<~SQL)
          select  users.id
          from    Users
          where   users.active = true;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "does not add aliases" do
        expect(output).to match_formatted_text(<<~SQL)
          select  users.id,
                  orders.total

          from    Users
                  inner join Orders on orders.user_id = users.id;
        SQL
      end
    end

    context "with an underscore-separated table name" do
      let(:value) { "SELECT active_storage_blobs.id FROM active_storage_blobs" }

      it "PascalCases the table name without an alias" do
        expect(output).to match_formatted_text(<<~SQL)
          select  active_storage_blobs.id
          from    Active_Storage_Blobs;
        SQL
      end
    end
  end

  ############################################################################
  ## alias_strategy: callable
  ############################################################################

  context "when alias_strategy is a callable" do
    let(:config_value) { ->(table_name) { "tbl_#{table_name[0..2]}" } }

    context "with a simple query" do
      let(:value) { "SELECT users.id FROM users WHERE users.active = true" }

      it "uses the callable for alias generation and replaces references" do
        expect(output).to match_formatted_text(<<~SQL)
          select  tbl_use.id
          from    Users tbl_use
          where   tbl_use.active = true;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "uses the callable for each table alias" do
        expect(output).to match_formatted_text(<<~SQL)
          select  tbl_use.id,
                  tbl_ord.total

          from    Users tbl_use
                  inner join Orders tbl_ord on tbl_ord.user_id = tbl_use.id;
        SQL
      end
    end
  end
end
