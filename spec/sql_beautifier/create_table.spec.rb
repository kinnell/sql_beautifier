# frozen_string_literal: true

RSpec.describe SqlBeautifier::CreateTable do
  describe ".parse" do
    let(:result) { described_class.parse(value) }

    context "with a non-CREATE statement" do
      let(:value) { "select id from users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a CREATE TABLE AS query" do
      let(:value) { "create table foo as (select 1)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with an identifier starting with 'create'" do
      let(:value) { "create_backup(100)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without the TABLE keyword" do
      let(:value) { "create index idx_users_name on users (name)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without a table name" do
      let(:value) { "create table (id bigint)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without column definitions" do
      let(:value) { "create table users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a simple CREATE TABLE" do
      let(:value) { "create table users (id bigint)" }

      it "returns a CreateTable" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "parses the column definitions" do
        expect(result.column_definitions).to eq("id bigint")
      end

      it "has no modifier" do
        expect(result.modifier).to be_nil
      end

      it "does not set :if_not_exists" do
        expect(result.if_not_exists).to be false
      end
    end

    context "with CREATE TEMPORARY TABLE" do
      let(:value) { "create temporary table temp_export_constituents (id bigint)" }

      it "returns a CreateTable" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("temp_export_constituents")
      end

      it "extracts the modifier" do
        expect(result.modifier).to eq("temporary")
      end

      it "parses the column definitions" do
        expect(result.column_definitions).to eq("id bigint")
      end
    end

    context "with CREATE TEMP TABLE" do
      let(:value) { "create temp table foo (id bigint)" }

      it "extracts the modifier" do
        expect(result.modifier).to eq("temp")
      end
    end

    context "with CREATE UNLOGGED TABLE" do
      let(:value) { "create unlogged table foo (id bigint)" }

      it "extracts the modifier" do
        expect(result.modifier).to eq("unlogged")
      end
    end

    context "with CREATE LOCAL TABLE" do
      let(:value) { "create local table foo (id bigint)" }

      it "extracts the modifier" do
        expect(result.modifier).to eq("local")
      end
    end

    context "with IF NOT EXISTS" do
      let(:value) { "create table if not exists users (id bigint)" }

      it "sets :if_not_exists" do
        expect(result.if_not_exists).to be true
      end
    end

    context "with a modifier and IF NOT EXISTS" do
      let(:value) { "create temp table if not exists foo (id bigint)" }

      it "extracts the modifier" do
        expect(result.modifier).to eq("temp")
      end

      it "sets :if_not_exists" do
        expect(result.if_not_exists).to be true
      end
    end

    context "with multiple column definitions" do
      let(:value) { "create table users (id bigint, name text, email varchar(255))" }

      it "parses all column definitions" do
        expect(result.column_definitions).to eq("id bigint, name text, email varchar(255)")
      end
    end

    context "with a quoted table name" do
      let(:result) { described_class.parse('create table "my table" (id bigint)') }

      it "preserves the quoted identifier" do
        expect(result.table_name).to eq('"my table"')
      end
    end

    context "with uppercase input" do
      let(:value) { "CREATE TEMPORARY TABLE TEMP_EXPORT_CONSTITUENTS (ID BIGINT)" }

      it "returns a CreateTable" do
        expect(result).to be_a(described_class)
      end
    end

    context "with unclosed parentheses" do
      let(:value) { "create table users (id bigint" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with empty parentheses" do
      let(:value) { "create table users ()" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with trailing WITH clause" do
      let(:value) { "create table users (id bigint) with (fillfactor = 70)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with trailing TABLESPACE clause" do
      let(:value) { "create table users (id bigint) tablespace fast_storage" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#render" do
    let(:output) { described_class.parse(value).render }

    context "with a simple CREATE TABLE" do
      let(:value) { "create table users (id bigint)" }

      it "formats with PascalCase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          create table Users (id bigint)
        SQL
      end
    end

    context "with CREATE TEMPORARY TABLE" do
      let(:value) { "create temporary table temp_export_constituents (id bigint)" }

      it "formats with modifier and PascalCase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          create temporary table Temp_Export_Constituents (id bigint)
        SQL
      end
    end

    context "with CREATE TEMP TABLE" do
      let(:value) { "create temp table foo (id bigint)" }

      it "formats with the temp modifier" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo (id bigint)
        SQL
      end
    end

    context "with IF NOT EXISTS" do
      let(:value) { "create temp table if not exists foo (id bigint)" }

      it "includes if not exists in the preamble" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table if not exists Foo (id bigint)
        SQL
      end
    end

    context "with multiple column definitions" do
      let(:value) { "create table users (id bigint, name text, email varchar(255))" }

      it "preserves column definitions" do
        expect(output).to match_formatted_text(<<~SQL)
          create table Users (id bigint, name text, email varchar(255))
        SQL
      end
    end

    context "with an underscore table name" do
      let(:value) { "create temp table tmp_export_ids (id bigint)" }

      it "formats the table name with PascalCase" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Tmp_Export_Ids (id bigint)
        SQL
      end
    end

    context "with a quoted table name" do
      let(:output) { described_class.parse('create table "my table" (id bigint)').render }

      it "preserves the quoted identifier" do
        expect(output).to match_formatted_text(<<~SQL)
          create table "my table" (id bigint)
        SQL
      end
    end

    context "with :keyword_case set to :upper" do
      let(:value) { "create temporary table temp_export_constituents (id bigint)" }

      before do
        SqlBeautifier.configure do |config|
          config.keyword_case = :upper
        end
      end

      it "uppercases the keywords" do
        expect(output).to match_formatted_text(<<~SQL)
          CREATE TEMPORARY TABLE Temp_Export_Constituents (id bigint)
        SQL
      end
    end

    context "with :table_name_format set to :lowercase" do
      let(:value) { "create temporary table temp_export_constituents (id bigint)" }

      before do
        SqlBeautifier.configure do |config|
          config.table_name_format = :lowercase
        end
      end

      it "uses lowercase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          create temporary table temp_export_constituents (id bigint)
        SQL
      end
    end
  end
end
