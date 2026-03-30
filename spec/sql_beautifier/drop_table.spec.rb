# frozen_string_literal: true

RSpec.describe SqlBeautifier::DropTable do
  describe ".parse" do
    let(:result) { described_class.parse(value) }

    context "with a non-DROP statement" do
      let(:value) { "select id from users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with DROP without TABLE" do
      let(:value) { "drop index idx_users_name" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with an identifier starting with 'drop'" do
      let(:value) { "drop_backup(100)" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with DROP TABLE" do
      let(:value) { "drop table users" }

      it "returns a DropTable" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "does not set :if_exists" do
        expect(result.if_exists).to be false
      end
    end

    context "with DROP TABLE IF EXISTS" do
      let(:value) { "drop table if exists users" }

      it "returns a DropTable" do
        expect(result).to be_a(described_class)
      end

      it "parses the table name" do
        expect(result.table_name).to eq("users")
      end

      it "sets :if_exists" do
        expect(result.if_exists).to be true
      end
    end

    context "with uppercase DROP TABLE IF EXISTS" do
      let(:value) { "DROP TABLE IF EXISTS USERS" }

      it "returns a DropTable" do
        expect(result).to be_a(described_class)
      end
    end

    context "with an underscore table name" do
      let(:value) { "drop table if exists temp_export_constituents" }

      it "preserves the raw table name" do
        expect(result.table_name).to eq("temp_export_constituents")
      end
    end

    context "with a quoted table name" do
      let(:result) { described_class.parse('drop table "my table"') }

      it "preserves the quoted identifier" do
        expect(result.table_name).to eq('"my table"')
      end
    end

    context "with DROP TABLE IF but not EXISTS" do
      let(:value) { "drop table if users" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without a table name" do
      let(:value) { "drop table" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "without a table name after IF EXISTS" do
      let(:value) { "drop table if exists" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with multiple table names" do
      let(:value) { "drop table users, admins" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with CASCADE suffix" do
      let(:value) { "drop table users cascade" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with RESTRICT suffix" do
      let(:value) { "drop table users restrict" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#render" do
    let(:output) { described_class.parse(value).render }

    context "with DROP TABLE" do
      let(:value) { "drop table users" }

      it "formats with PascalCase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table Users
        SQL
      end
    end

    context "with DROP TABLE IF EXISTS" do
      let(:value) { "drop table if exists users" }

      it "formats with IF EXISTS and PascalCase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table if exists Users
        SQL
      end
    end

    context "with an underscore table name" do
      let(:value) { "drop table if exists temp_export_constituents" }

      it "formats the table name with PascalCase" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table if exists Temp_Export_Constituents
        SQL
      end
    end

    context "with a quoted table name" do
      let(:output) { described_class.parse('drop table "my table"').render }

      it "preserves the quoted identifier" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table "my table"
        SQL
      end
    end

    context "with uppercase input" do
      let(:value) { "DROP TABLE IF EXISTS TEMP_EXPORT_CONSTITUENTS" }

      it "formats with lowercase keywords and PascalCase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table if exists Temp_Export_Constituents
        SQL
      end
    end

    context "with :keyword_case set to :upper" do
      let(:value) { "drop table if exists users" }

      before do
        SqlBeautifier.configure do |config|
          config.keyword_case = :upper
        end
      end

      it "uppercases the keywords" do
        expect(output).to match_formatted_text(<<~SQL)
          DROP TABLE IF EXISTS Users
        SQL
      end
    end

    context "with :table_name_format set to :lowercase" do
      let(:value) { "drop table if exists temp_export_constituents" }

      before do
        SqlBeautifier.configure do |config|
          config.table_name_format = :lowercase
        end
      end

      it "uses lowercase table name" do
        expect(output).to match_formatted_text(<<~SQL)
          drop table if exists temp_export_constituents
        SQL
      end
    end
  end
end
