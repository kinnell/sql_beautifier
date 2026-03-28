# frozen_string_literal: true

RSpec.describe SqlBeautifier do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a whitespace-only string" do
      let(:value) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a valid query" do
      let(:value) { "SELECT id FROM users" }

      it "formats SQL" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end

      it "appends a trailing semicolon by default" do
        expect(output).to end_with(";\n")
      end
    end

    context "with :trailing_semicolon set to false" do
      let(:value) { "SELECT id FROM users" }

      before { SqlBeautifier.configure { |config| config.trailing_semicolon = false } }

      it "does not append a trailing semicolon" do
        expect(output).not_to end_with(";\n")
        expect(output).to end_with("u\n")
      end
    end

    context "with two semicolon-separated statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      it "formats each statement independently" do
        expect(output).to include("from    Constituents c;")
        expect(output).to include("from    Departments d;")
      end

      it "separates statements with a blank line" do
        expect(output).to include(";\n\n")
      end
    end

    context "with two concatenated statements without semicolons" do
      let(:value) { "SELECT id FROM constituents SELECT id FROM departments" }

      it "detects and formats each statement independently" do
        expect(output).to include("from    Constituents c;")
        expect(output).to include("from    Departments d;")
      end
    end

    context "with trailing_semicolon disabled and multiple statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      before { SqlBeautifier.configure { |config| config.trailing_semicolon = false } }

      it "does not append semicolons" do
        expect(output).not_to include(";")
      end

      it "separates statements with a blank line" do
        expect(output).to include("c\n\nselect")
      end
    end
  end

  describe ".call with per-call config" do
    let(:value) { "SELECT id FROM users" }

    context "with a single override" do
      let(:output) { described_class.call(value, trailing_semicolon: false) }

      it "applies the override" do
        expect(output).not_to include(";")
        expect(output).to end_with("u\n")
      end
    end

    context "with multiple overrides" do
      let(:output) { described_class.call(value, trailing_semicolon: false, keyword_case: :upper) }

      it "applies all overrides" do
        expect(output).not_to include(";")
        expect(output).to include("SELECT")
        expect(output).to include("FROM")
      end
    end

    context "when a global config is set" do
      before { described_class.configure { |config| config.keyword_case = :upper } }

      let(:output) { described_class.call(value, keyword_case: :lower) }

      it "overrides the global config" do
        expect(output).to include("select")
        expect(output).not_to include("SELECT")
      end
    end

    context "when the per-call config does not include a key" do
      before { described_class.configure { |config| config.trailing_semicolon = false } }

      let(:output) { described_class.call(value, keyword_case: :upper) }

      it "falls back to the global config for unspecified keys" do
        expect(output).to include("SELECT")
        expect(output).not_to include(";")
      end
    end

    context "with an unknown key" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, bogus_key: true) }.to raise_error(ArgumentError, %r{bogus_key})
      end
    end

    context "with nil config" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, nil) }.to raise_error(ArgumentError, %r{Hash})
      end
    end

    context "with a non-Hash config" do
      it "raises an ArgumentError" do
        expect { described_class.call(value, "bad") }.to raise_error(ArgumentError, %r{Hash})
      end
    end

    context "when the call completes" do
      it "does not mutate the global configuration" do
        described_class.call(value, trailing_semicolon: false, keyword_case: :upper)

        expect(described_class.configuration.trailing_semicolon).to eq(true)
        expect(described_class.configuration.keyword_case).to eq(:lower)
      end
    end

    context "with an empty config hash" do
      let(:output) { described_class.call(value, {}) }

      it "behaves identically to calling without config" do
        expect(output).to eq(described_class.call(value))
      end
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(SqlBeautifier::Configuration)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.keyword_column_width = 12
      end

      expect(described_class.configuration.keyword_column_width).to eq(12)
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration with a fresh instance" do
      original = described_class.configuration
      described_class.configure { |config| config.keyword_column_width = 12 }

      described_class.reset_configuration!

      expect(described_class.configuration).not_to equal(original)
      expect(described_class.configuration.keyword_column_width).to eq(8)
    end
  end

  ############################################################################
  ## Comment Preservation
  ############################################################################

  describe "comment preservation" do
    let(:output) { described_class.call(value) }

    context "with a banner comment before a statement" do
      let(:value) { "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nSELECT id FROM users" }

      it "preserves the banner comment" do
        expect(output).to start_with("--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\n")
      end

      it "formats the SQL after the banner" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end
    end

    context "with a separate-line comment between two statements" do
      let(:value) { "SELECT id FROM users;\n-- second query\nSELECT name FROM departments" }

      it "preserves the comment between formatted statements" do
        expect(output).to include("-- second query")
      end

      it "formats both statements" do
        expect(output).to include("from    Users u")
        expect(output).to include("from    Departments d")
      end
    end

    context "with an inline comment in a SELECT clause" do
      let(:value) { "SELECT id -- primary key\n, name FROM users" }

      it "preserves the inline comment" do
        expect(output).to include("-- primary key")
      end

      it "formats the query" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a block comment inline" do
      let(:value) { "SELECT /* main columns */ id, name FROM users" }

      it "preserves the block comment" do
        expect(output).to include("/* main columns */")
      end

      it "formats the query" do
        expect(output).to include("from    Users u")
      end
    end

    context "with removable_comment_types set to :all" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- table" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = :all } }

      it "strips all comments" do
        expect(output).not_to include("banner")
        expect(output).not_to include("pk")
        expect(output).not_to include("table")
        expect(output).not_to include("--")
        expect(output).not_to include("/*")
      end

      it "formats the query normally" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end
    end

    context "with removable_comment_types set to [:inline, :blocks]" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- table" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = %i[inline blocks] } }

      it "strips inline and block comments" do
        expect(output).not_to include("/* pk */")
        expect(output).not_to include("-- table")
      end

      it "preserves separate-line comments" do
        expect(output).to include("-- banner")
      end
    end

    context "with removable_comment_types set to [:separate_line]" do
      let(:value) { "-- banner\nSELECT id /* pk */ FROM users -- inline" }

      before { SqlBeautifier.configure { |config| config.removable_comment_types = [:separate_line] } }

      it "strips separate-line comments" do
        expect(output).not_to include("-- banner")
      end

      it "preserves inline and block comments" do
        expect(output).to include("/* pk */")
        expect(output).to include("-- inline")
      end
    end

    context "with per-call config overriding removable_comment_types" do
      let(:value) { "-- banner\nSELECT id FROM users" }
      let(:output) { described_class.call(value, removable_comment_types: :all) }

      it "strips comments per the override" do
        expect(output).not_to include("-- banner")
      end
    end

    context "with comments inside string literals" do
      let(:value) { "SELECT * FROM users WHERE name = 'test--value' AND bio = 'has /* stars */'" }

      it "preserves comment-like characters inside strings" do
        expect(output).to include("'test--value'")
        expect(output).to include("'has /* stars */'")
      end
    end

    context "with an inline comment after a trailing semicolon" do
      let(:value) { "SELECT id FROM users; -- done" }

      it "preserves the inline comment" do
        expect(output).to include("-- done")
      end

      it "formats the statement" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a comment-only input" do
      let(:value) { "-- just a comment" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  ############################################################################
  ## CASE Expressions
  ############################################################################

  describe "CASE expressions" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with a searched CASE in SELECT" do
      let(:value) { "SELECT id, CASE WHEN status = 1 THEN 'active' WHEN status = 2 THEN 'inactive' ELSE 'unknown' END AS label FROM users" }

      it "preserves the CASE expression inline" do
        expect(output).to include("case when status = 1 then 'active' when status = 2 then 'inactive' else 'unknown' end as label")
      end

      it "formats surrounding clauses" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a simple CASE in SELECT" do
      let(:value) { "SELECT CASE status WHEN 1 THEN 'active' ELSE 'unknown' END FROM users" }

      it "preserves the CASE expression inline" do
        expect(output).to include("case status when 1 then 'active' else 'unknown' end")
      end
    end

    context "with a CASE expression in WHERE" do
      let(:value) { "SELECT id FROM users WHERE CASE WHEN role = 'admin' THEN true ELSE false END = true" }

      it "preserves the CASE expression in the WHERE clause" do
        expect(output).to include("where   case when role = 'admin' then true else false end = true")
      end
    end
  end

  ############################################################################
  ## Window Functions
  ############################################################################

  describe "window functions" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with ROW_NUMBER and PARTITION BY" do
      let(:value) { "SELECT id, name, ROW_NUMBER() OVER (PARTITION BY department ORDER BY created_at DESC) AS row_num FROM users" }

      it "preserves the window function inline" do
        expect(output).to include("row_number() over (partition by department order by created_at desc) as row_num")
      end

      it "formats surrounding clauses" do
        expect(output).to include("from    Users u")
      end
    end

    context "with a window function without PARTITION BY" do
      let(:value) { "SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) AS row_num FROM users" }

      it "preserves the window function inline" do
        expect(output).to include("row_number() over (order by created_at) as row_num")
      end
    end
  end

  ############################################################################
  ## Set Operators (UNION, INTERSECT, EXCEPT)
  ############################################################################

  describe "set operators" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with UNION ALL" do
      let(:value) { "SELECT id, name FROM users WHERE active = true UNION ALL SELECT id, name FROM archived_users WHERE active = true" }

      it "formats both sides of the UNION ALL" do
        expect(output).to include("from    Users u")
        expect(output).to include("from    Archived_Users au")
      end
    end

    context "with a simple UNION" do
      let(:value) { "SELECT id FROM users UNION SELECT id FROM departments" }

      it "formats both sides of the UNION" do
        expect(output).to include("from    Users")
        expect(output).to include("from    Departments d")
      end
    end

    context "with INTERSECT" do
      let(:value) { "SELECT id FROM users INTERSECT SELECT id FROM departments" }

      it "formats both sides of the INTERSECT" do
        expect(output).to include("from    Users")
        expect(output).to include("from    Departments d")
      end
    end

    context "with EXCEPT" do
      let(:value) { "SELECT id FROM users EXCEPT SELECT id FROM departments" }

      it "formats both sides of the EXCEPT" do
        expect(output).to include("from    Users")
        expect(output).to include("from    Departments d")
      end
    end
  end

  ############################################################################
  ## OFFSET
  ############################################################################

  describe "OFFSET" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with LIMIT and OFFSET" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25 OFFSET 50" }

      it "formats the LIMIT with OFFSET" do
        expect(output).to include("limit 25 offset 50")
      end

      it "formats surrounding clauses" do
        expect(output).to include("order by created_at desc")
      end
    end
  end

  ############################################################################
  ## Type Casting
  ############################################################################

  describe "type casting" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with CAST expression" do
      let(:value) { "SELECT CAST(created_at AS date), name FROM users" }

      it "preserves the CAST expression" do
        expect(output).to include("cast(created_at as date)")
      end
    end

    context "with PostgreSQL :: cast" do
      let(:value) { "SELECT id::text, created_at::date FROM users" }

      it "preserves the :: cast syntax" do
        expect(output).to include("id::text")
        expect(output).to include("created_at::date")
      end
    end

    context "with CAST in WHERE" do
      let(:value) { "SELECT id FROM users WHERE CAST(score AS integer) > 50" }

      it "preserves the CAST in the WHERE clause" do
        expect(output).to include("where   cast(score as integer) > 50")
      end
    end
  end

  ############################################################################
  ## Implicit Joins (Comma-Separated FROM)
  ############################################################################

  describe "implicit joins" do
    let(:output) { described_class.call(value, trailing_semicolon: false) }

    context "with comma-separated tables in FROM" do
      let(:value) { "SELECT users.id, orders.total FROM users, orders WHERE orders.user_id = users.id AND users.active = true" }

      it "formats the FROM clause with comma-separated tables" do
        expect(output).to include("from    Users, orders")
      end

      it "formats the WHERE clause" do
        expect(output).to include("where   orders.user_id = users.id")
        expect(output).to include("and users.active = true")
      end
    end
  end
end
