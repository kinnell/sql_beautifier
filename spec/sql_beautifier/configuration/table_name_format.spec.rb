# frozen_string_literal: true

RSpec.describe "table_name_format configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.table_name_format = config_value
    end
  end

  ############################################################################
  ## table_name_format: :pascal_case (default)
  ############################################################################

  context "when table_name_format is :pascal_case (default)" do
    let(:config_value) { :pascal_case }

    context "with a single-word table name" do
      let(:value) { "SELECT id FROM users" }

      it "capitalizes the table name" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with an underscore-separated table name" do
      let(:value) { "SELECT id FROM active_storage_blobs" }

      it "capitalizes each segment" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Active_Storage_Blobs asb;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "PascalCases all table names" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id,
                  o.total

          from    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active_users AS (SELECT id FROM users) SELECT * FROM active_users" }

      it "PascalCases the CTE reference in FROM" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active_users as (
                      select  id
                      from    Users u
                  )

          select  *
          from    Active_Users au;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE export_data AS (SELECT id FROM users)" }

      it "PascalCases the created table name" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Export_Data as (
              select  id
              from    Users u
          );
        SQL
      end
    end
  end

  ############################################################################
  ## table_name_format: :lowercase
  ############################################################################

  context "when table_name_format is :lowercase" do
    let(:config_value) { :lowercase }

    context "with a single-word table name" do
      let(:value) { "SELECT id FROM users" }

      it "keeps the table name lowercase" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    users u;
        SQL
      end
    end

    context "with an underscore-separated table name" do
      let(:value) { "SELECT id FROM active_storage_blobs" }

      it "keeps the table name lowercase" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    active_storage_blobs asb;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id, orders.total FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "keeps all table names lowercase" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id,
                  o.total

          from    users u
                  inner join orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active_users AS (SELECT id FROM users) SELECT * FROM active_users" }

      it "keeps CTE reference lowercase in FROM" do
        expect(output).to match_formatted_text(<<~SQL)
          with    active_users as (
                      select  id
                      from    users u
                  )

          select  *
          from    active_users au;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE export_data AS (SELECT id FROM users)" }

      it "keeps the created table name lowercase" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table export_data as (
              select  id
              from    users u
          );
        SQL
      end
    end
  end
end
