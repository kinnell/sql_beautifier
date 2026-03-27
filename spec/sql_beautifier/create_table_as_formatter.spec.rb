# frozen_string_literal: true

RSpec.describe SqlBeautifier::CreateTableAsFormatter do
  describe ".create_table_as_query?" do
    subject(:create_table_as_query) { described_class.create_table_as_query?(sql) }

    context "with a CREATE TABLE AS query" do
      let(:sql) { "create table foo as (select 1)" }

      it "returns true" do
        expect(create_table_as_query).to be true
      end
    end

    context "with a CREATE TEMP TABLE AS query" do
      let(:sql) { "create temp table foo as (select 1)" }

      it "returns true" do
        expect(create_table_as_query).to be true
      end
    end

    context "with an uppercase CREATE TABLE AS query" do
      let(:sql) { "CREATE TABLE foo AS (SELECT 1)" }

      it "returns true" do
        expect(create_table_as_query).to be true
      end
    end

    context "with a SELECT query" do
      let(:sql) { "select * from users" }

      it "returns false" do
        expect(create_table_as_query).to be false
      end
    end

    context "with a WITH query" do
      let(:sql) { "with cte as (select 1) select * from cte" }

      it "returns false" do
        expect(create_table_as_query).to be false
      end
    end

    context "with an identifier starting with 'create'" do
      let(:sql) { "create_backup(100)" }

      it "returns false" do
        expect(create_table_as_query).to be false
      end
    end
  end

  describe ".parse" do
    subject(:result) { described_class.parse(sql) }

    let(:preamble) { result&.dig(:preamble) }
    let(:body) { result&.dig(:body) }
    let(:suffix) { result&.dig(:suffix) }

    context "with a basic CREATE TABLE AS" do
      let(:sql) { "create table foo as (select id from users)" }

      it "parses the preamble" do
        expect(preamble).to eq("create table Foo as")
      end

      it "parses the body" do
        expect(body).to eq("select id from users")
      end

      it "has no suffix" do
        expect(suffix).to be_nil
      end
    end

    context "with the TEMP modifier" do
      let(:sql) { "create temp table foo as (select 1)" }

      it "includes the modifier in the preamble" do
        expect(preamble).to eq("create temp table Foo as")
      end
    end

    context "with the TEMPORARY modifier" do
      let(:sql) { "create temporary table foo as (select 1)" }

      it "includes the modifier in the preamble" do
        expect(preamble).to eq("create temporary table Foo as")
      end
    end

    context "with the UNLOGGED modifier" do
      let(:sql) { "create unlogged table foo as (select 1)" }

      it "includes the modifier in the preamble" do
        expect(preamble).to eq("create unlogged table Foo as")
      end
    end

    context "with the LOCAL modifier" do
      let(:sql) { "create local table foo as (select 1)" }

      it "includes the modifier in the preamble" do
        expect(preamble).to eq("create local table Foo as")
      end
    end

    context "with IF NOT EXISTS" do
      let(:sql) { "create table if not exists foo as (select 1)" }

      it "includes if not exists in the preamble" do
        expect(preamble).to eq("create table if not exists Foo as")
      end
    end

    context "with a modifier and IF NOT EXISTS" do
      let(:sql) { "create temp table if not exists foo as (select 1)" }

      it "includes both in the preamble" do
        expect(preamble).to eq("create temp table if not exists Foo as")
      end
    end

    context "with a quoted table name" do
      let(:sql) { 'create table "my table" as (select 1)' }

      it "preserves the quoted identifier in the preamble" do
        expect(preamble).to eq('create table "my table" as')
      end

      it "parses the body" do
        expect(body).to eq("select 1")
      end
    end

    context "with a quoted table name containing escaped quotes" do
      let(:sql) { 'create table "my ""special"" table" as (select 1)' }

      it "preserves the escaped quoted identifier" do
        expect(preamble).to eq('create table "my ""special"" table" as')
      end
    end

    context "with an underscore table name" do
      let(:sql) { "create table tmp_export_ids as (select 1)" }

      it "formats the table name with PascalCase" do
        expect(preamble).to eq("create table Tmp_Export_Ids as")
      end
    end

    context "with uppercase input" do
      let(:sql) { "CREATE TEMP TABLE FOO AS (SELECT 1)" }

      it "parses the preamble with formatted keywords" do
        expect(preamble).to eq("create temp table Foo as")
      end

      it "parses the body" do
        expect(body).to eq("SELECT 1")
      end
    end

    context "without parentheses around the body" do
      let(:sql) { "create table foo as select id from users" }

      it "extracts the body without parentheses" do
        expect(body).to eq("select id from users")
      end
    end

    context "with nested parentheses in the body" do
      let(:sql) { "create table foo as (select count(id) from users where active = true)" }

      it "parses the full body including function calls" do
        expect(body).to eq("select count(id) from users where active = true")
      end
    end

    context "with string literals containing parentheses in the body" do
      let(:sql) { "create table foo as (select id from users where name = 'O''Brien')" }

      it "parses the full body including the string literal" do
        expect(body).to eq("select id from users where name = 'O''Brien'")
      end
    end

    context "with a parenthesized body and WITH DATA suffix" do
      let(:sql) { "create temp table foo as (select id from users) with data" }

      it "parses the body without the suffix" do
        expect(body).to eq("select id from users")
      end

      it "captures the suffix" do
        expect(suffix).to eq("with data")
      end
    end

    context "with a parenthesized body and WITH NO DATA suffix" do
      let(:sql) { "create temp table foo as (select id from users) with no data" }

      it "parses the body without the suffix" do
        expect(body).to eq("select id from users")
      end

      it "captures the suffix" do
        expect(suffix).to eq("with no data")
      end
    end

    context "with an uppercase WITH NO DATA suffix" do
      let(:sql) { "CREATE TEMP TABLE FOO AS (SELECT 1) WITH NO DATA" }

      it "captures the suffix" do
        expect(suffix).to eq("WITH NO DATA")
      end
    end

    context "without parentheses and WITH DATA suffix" do
      let(:sql) { "create temp table foo as select id from users with data" }

      it "parses the body without the suffix" do
        expect(body).to eq("select id from users")
      end

      it "captures the suffix" do
        expect(suffix).to eq("with data")
      end
    end

    context "without parentheses and WITH NO DATA suffix" do
      let(:sql) { "create temp table foo as select id from users with no data" }

      it "parses the body without the suffix" do
        expect(body).to eq("select id from users")
      end

      it "captures the suffix" do
        expect(suffix).to eq("with no data")
      end
    end

    context "without the TABLE keyword" do
      let(:sql) { "create foo as (select 1)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without the AS keyword" do
      let(:sql) { "create table foo (id integer, name text)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without a table name" do
      let(:sql) { "create table as (select 1)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without a body after AS" do
      let(:sql) { "create table foo as" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with unclosed parentheses in the body" do
      let(:sql) { "create table foo as (select id from users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a CREATE VIEW statement" do
      let(:sql) { "create view foo as select id from users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a CREATE MATERIALIZED VIEW statement" do
      let(:sql) { "create materialized view foo as select id from users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a CREATE INDEX statement" do
      let(:sql) { "create index idx_users_name on users (name)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe ".format" do
    subject(:output) { described_class.format(sql) }

    ############################################################################
    ## Non-matching input
    ############################################################################

    context "with a SELECT query" do
      let(:sql) { "select * from users" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a WITH query" do
      let(:sql) { "with cte as (select 1) select * from cte" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a CREATE INDEX statement" do
      let(:sql) { "create index idx_users_name on users (name)" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a CREATE TABLE with column definitions" do
      let(:sql) { "create table users (id integer, name text)" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a CREATE TABLE AS without a body" do
      let(:sql) { "create table foo as" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a CREATE VIEW statement" do
      let(:sql) { "create view foo as select id from users" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a CREATE MATERIALIZED VIEW statement" do
      let(:sql) { "create materialized view foo as select id from users" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an empty string" do
      let(:sql) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    ############################################################################
    ## Basic formatting
    ############################################################################

    context "with a basic CREATE TABLE AS" do
      let(:sql) { "create table foo as (select id from users)" }

      it "formats the preamble and indented body" do
        expect(output).to eq(<<~SQL)
          create table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with uppercase input" do
      let(:sql) { "CREATE TABLE FOO AS (SELECT ID FROM USERS)" }

      it "formats with lowercase keywords and PascalCase table name" do
        expect(output).to eq(<<~SQL)
          create table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with CREATE TEMP TABLE" do
      let(:sql) { "create temp table foo as (select id from users)" }

      it "formats with the temp modifier" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    context "with CREATE TEMPORARY TABLE" do
      let(:sql) { "create temporary table foo as (select id from users)" }

      it "formats with the temporary modifier" do
        expect(output).to start_with("create temporary table Foo as (")
      end
    end

    context "with CREATE UNLOGGED TABLE" do
      let(:sql) { "create unlogged table foo as (select id from users)" }

      it "formats with the unlogged modifier" do
        expect(output).to start_with("create unlogged table Foo as (")
      end
    end

    context "with CREATE LOCAL TABLE" do
      let(:sql) { "create local table foo as (select id from users)" }

      it "formats with the local modifier" do
        expect(output).to start_with("create local table Foo as (")
      end
    end

    context "with IF NOT EXISTS" do
      let(:sql) { "create temp table if not exists foo as (select id from users)" }

      it "includes if not exists in the preamble" do
        expect(output).to start_with("create temp table if not exists Foo as (")
      end
    end

    context "with IF NOT EXISTS without a modifier" do
      let(:sql) { "create table if not exists foo as (select id from users)" }

      it "includes if not exists in the preamble" do
        expect(output).to start_with("create table if not exists Foo as (")
      end
    end

    context "with an underscore table name" do
      let(:sql) { "create temp table tmp_export_ids as (select id from users)" }

      it "formats the table name with PascalCase" do
        expect(output).to start_with("create temp table Tmp_Export_Ids as (")
      end
    end

    context "with a quoted table name" do
      let(:sql) { 'create table "my table" as (select id from users)' }

      it "preserves the quoted identifier in the preamble" do
        expect(output).to start_with('create table "my table" as (')
      end
    end

    context "with a quoted table name containing escaped quotes" do
      let(:sql) { 'create table "my ""special"" table" as (select id from users)' }

      it "preserves the escaped quoted identifier" do
        expect(output).to start_with('create table "my ""special"" table" as (')
      end
    end

    context "without parentheses around the body" do
      let(:sql) { "create temp table foo as select id from users" }

      it "wraps the body in parentheses" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          )
        SQL
      end
    end

    ############################################################################
    ## WITH [NO] DATA suffix
    ############################################################################

    context "with WITH DATA after a parenthesized body" do
      let(:sql) { "create temp table foo as (select id from users) with data" }

      it "appends the suffix after the closing parenthesis" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          ) with data
        SQL
      end
    end

    context "with WITH NO DATA after a parenthesized body" do
      let(:sql) { "create temp table foo as (select id from users) with no data" }

      it "appends the suffix after the closing parenthesis" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          ) with no data
        SQL
      end
    end

    context "with WITH NO DATA after an unparenthesized body" do
      let(:sql) { "create temp table foo as select id from users with no data" }

      it "wraps the body in parentheses and appends the suffix" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          ) with no data
        SQL
      end
    end

    context "with WITH NO DATA and :keyword_case set to :upper" do
      let(:sql) { "create temp table foo as (select id from users) with no data" }

      before { SqlBeautifier.configure { |config| config.keyword_case = :upper } }

      it "uppercases the suffix keywords" do
        expect(output.strip).to end_with(") WITH NO DATA")
      end
    end

    ############################################################################
    ## Body formatting delegation
    ############################################################################

    context "with a body containing JOINs and WHERE conditions" do
      let(:sql) { "create temp table foo as (select users.id from users inner join orders on orders.user_id = users.id where users.active = true)" }

      it "formats the body with full clause layout" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  u.id

              from    Users u
                      inner join Orders o on o.user_id = u.id

              where   u.active = true
          )
        SQL
      end
    end

    context "with a body containing a CTE" do
      let(:sql) { "create temp table foo as (with active as (select id from users where active = true) select * from active)" }

      it "formats the CTE body" do
        expect(output).to include("with    active as (")
      end

      it "formats the CTE main query" do
        expect(output).to include("select  *")
      end

      it "starts with the preamble" do
        expect(output).to start_with("create temp table Foo as (")
      end

      it "closes with a parenthesis" do
        expect(output.strip).to end_with(")")
      end
    end

    context "with a body containing a subquery" do
      let(:sql) { "create temp table foo as (select id from users where id in (select user_id from orders))" }

      it "formats the outer WHERE with the subquery" do
        expect(output).to include("where   id in (")
      end

      it "formats the inner subquery" do
        expect(output).to include("select  user_id")
      end
    end

    ############################################################################
    ## Configuration
    ############################################################################

    context "with :keyword_case set to :upper" do
      let(:sql) { "create temp table foo as (select id from users)" }

      before { SqlBeautifier.configure { |config| config.keyword_case = :upper } }

      it "uppercases keywords in the preamble" do
        expect(output).to start_with("CREATE TEMP TABLE Foo AS (")
      end

      it "uppercases keywords in the body" do
        expect(output).to include("SELECT  id")
      end
    end

    context "with :table_name_format set to :lowercase" do
      let(:sql) { "create temp table foo as (select id from users)" }

      before { SqlBeautifier.configure { |config| config.table_name_format = :lowercase } }

      it "uses lowercase table name in the preamble" do
        expect(output).to start_with("create temp table foo as (")
      end

      it "uses lowercase table names in the body" do
        expect(output).to include("from    users u")
      end
    end
  end
end
