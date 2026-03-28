# frozen_string_literal: true

RSpec.describe SqlBeautifier::StatementSplitter do
  describe ".split" do
    let(:output) { described_class.split(value) }

    context "with a single statement" do
      let(:value) { "SELECT id FROM users" }

      it "returns a single-element array" do
        expect(output).to eq(["SELECT id FROM users"])
      end
    end

    context "with a single statement and trailing semicolon" do
      let(:value) { "SELECT id FROM users;" }

      it "returns a single-element array without the semicolon" do
        expect(output).to eq(["SELECT id FROM users"])
      end
    end

    context "with two statements separated by a semicolon" do
      let(:value) { "SELECT id FROM users; SELECT id FROM departments" }

      it "returns two statements" do
        expect(output).to eq([
          "SELECT id FROM users",
          "SELECT id FROM departments",
        ])
      end
    end

    context "with two statements separated by a semicolon and trailing semicolon" do
      let(:value) { "SELECT id FROM users; SELECT id FROM departments;" }

      it "returns two statements without trailing semicolons" do
        expect(output).to eq([
          "SELECT id FROM users",
          "SELECT id FROM departments",
        ])
      end
    end

    context "with two concatenated statements without a semicolon" do
      let(:value) { "SELECT id FROM users SELECT id FROM departments" }

      it "splits on the second SELECT" do
        expect(output).to eq([
          "SELECT id FROM users",
          "SELECT id FROM departments",
        ])
      end
    end

    context "with a subquery in WHERE" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "does not split on the subquery SELECT" do
        expect(output).to eq(["SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)"])
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "does not split the CTE from the main query" do
        expect(output).to eq(["WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active"])
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "does not split the CREATE from the body" do
        expect(output).to eq(["CREATE TEMP TABLE foo AS (SELECT id FROM users)"])
      end
    end

    context "with a CREATE TABLE AS without parentheses" do
      let(:value) { "CREATE TEMP TABLE foo AS SELECT id FROM users" }

      it "does not split the CREATE from the body" do
        expect(output).to eq(["CREATE TEMP TABLE foo AS SELECT id FROM users"])
      end
    end

    context "with semicolons inside string literals" do
      let(:value) { "SELECT * FROM users WHERE name = 'foo;bar'" }

      it "does not split on semicolons inside strings" do
        expect(output).to eq(["SELECT * FROM users WHERE name = 'foo;bar'"])
      end
    end

    context "with an INSERT INTO ... SELECT" do
      let(:value) { "INSERT INTO targets (id, name) SELECT id, name FROM sources" }

      it "does not split the INSERT from the SELECT" do
        expect(output).to eq(["INSERT INTO targets (id, name) SELECT id, name FROM sources"])
      end
    end

    context "with empty input between semicolons" do
      let(:value) { "SELECT id FROM users;; SELECT id FROM departments" }

      it "skips empty segments" do
        expect(output).to eq([
          "SELECT id FROM users",
          "SELECT id FROM departments",
        ])
      end
    end

    context "with whitespace-only input" do
      let(:value) { "   " }

      it "returns an empty array" do
        expect(output).to eq([])
      end
    end

    context "with three concatenated statements" do
      let(:value) { "SELECT 1 FROM a SELECT 2 FROM b SELECT 3 FROM c" }

      it "splits into three statements" do
        expect(output).to eq([
          "SELECT 1 FROM a",
          "SELECT 2 FROM b",
          "SELECT 3 FROM c",
        ])
      end
    end

    context "with a mix of semicolons and concatenated statements" do
      let(:value) { "SELECT 1 FROM a; SELECT 2 FROM b SELECT 3 FROM c" }

      it "handles both splitting strategies" do
        expect(output).to eq([
          "SELECT 1 FROM a",
          "SELECT 2 FROM b",
          "SELECT 3 FROM c",
        ])
      end
    end

    context "with a CTE followed by a semicolon and another statement" do
      let(:value) { "WITH cte AS (SELECT id FROM users) SELECT * FROM cte; SELECT id FROM departments" }

      it "keeps the CTE intact and splits on the semicolon" do
        expect(output).to eq([
          "WITH cte AS (SELECT id FROM users) SELECT * FROM cte",
          "SELECT id FROM departments",
        ])
      end
    end

    context "with a sentinel-only segment after a semicolon" do
      let(:value) { "SELECT id FROM users; /*__sqlb_0__*/" }

      it "merges the sentinel back into the preceding statement" do
        expect(output).to eq(["SELECT id FROM users /*__sqlb_0__*/"])
      end
    end

    context "with multiple sentinels after a semicolon" do
      let(:value) { "SELECT id FROM users; /*__sqlb_0__*/ /*__sqlb_1__*/" }

      it "merges all sentinels back into the preceding statement" do
        expect(output).to eq(["SELECT id FROM users /*__sqlb_0__*/ /*__sqlb_1__*/"])
      end
    end

    context "with a sentinel-only segment between two statements" do
      let(:value) { "SELECT id FROM users; /*__sqlb_0__*/; SELECT id FROM departments" }

      it "merges the sentinel into the preceding statement" do
        expect(output).to eq([
          "SELECT id FROM users /*__sqlb_0__*/",
          "SELECT id FROM departments",
        ])
      end
    end
  end

  describe ".split_on_semicolons" do
    let(:output) { described_class.split_on_semicolons(value) }

    context "with no semicolons" do
      let(:value) { "SELECT id FROM users" }

      it "returns the input as a single element" do
        expect(output).to eq(["SELECT id FROM users"])
      end
    end

    context "with a semicolon between two statements" do
      let(:value) { "SELECT 1; SELECT 2" }

      it "splits into two elements" do
        expect(output).to eq(["SELECT 1", "SELECT 2"])
      end
    end

    context "with a semicolon inside single quotes" do
      let(:value) { "SELECT 'a;b' FROM users" }

      it "does not split inside string literals" do
        expect(output).to eq(["SELECT 'a;b' FROM users"])
      end
    end

    context "with a semicolon inside double-quoted identifiers" do
      let(:value) { 'SELECT "col;name" FROM users' }

      it "does not split inside quoted identifiers" do
        expect(output).to eq(['SELECT "col;name" FROM users'])
      end
    end

    context "with a semicolon inside parentheses" do
      let(:value) { "SELECT func(1; 2) FROM users" }

      it "does not split inside parentheses" do
        expect(output).to eq(["SELECT func(1; 2) FROM users"])
      end
    end

    context "with escaped single quotes" do
      let(:value) { "SELECT 'it''s; here' FROM users; SELECT 1" }

      it "handles escaped quotes and splits correctly" do
        expect(output).to eq(["SELECT 'it''s; here' FROM users", "SELECT 1"])
      end
    end

    context "with a semicolon inside a dollar-quoted string literal" do
      let(:value) { "SELECT $$a;b$$ AS payload FROM users; SELECT id FROM departments" }

      it "does not split inside the dollar-quoted string" do
        expect(output).to eq([
          "SELECT $$a;b$$ AS payload FROM users",
          "SELECT id FROM departments",
        ])
      end
    end
  end

  describe ".split_concatenated_statements" do
    let(:output) { described_class.split_concatenated_statements(value) }

    context "with a single statement" do
      let(:value) { "SELECT id FROM users" }

      it "returns the statement unchanged" do
        expect(output).to eq(["SELECT id FROM users"])
      end
    end

    context "with two concatenated SELECT statements" do
      let(:value) { "SELECT id FROM users SELECT name FROM departments" }

      it "splits at the second SELECT" do
        expect(output).to eq([
          "SELECT id FROM users",
          "SELECT name FROM departments",
        ])
      end
    end

    context "with a subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "does not split on the subquery" do
        expect(output).to eq(["SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)"])
      end
    end

    context "with a CTE" do
      let(:value) { "WITH cte AS (SELECT id FROM users) SELECT * FROM cte" }

      it "does not split the CTE main query" do
        expect(output).to eq(["WITH cte AS (SELECT id FROM users) SELECT * FROM cte"])
      end
    end

    context "with statement keywords inside string literals" do
      let(:value) { "SELECT 'SELECT FROM WHERE' FROM users" }

      it "does not split on keywords inside strings" do
        expect(output).to eq(["SELECT 'SELECT FROM WHERE' FROM users"])
      end
    end

    context "with an INSERT INTO ... SELECT" do
      let(:value) { "INSERT INTO targets (id, name) SELECT id, name FROM sources" }

      it "does not split the INSERT from the SELECT" do
        expect(output).to eq(["INSERT INTO targets (id, name) SELECT id, name FROM sources"])
      end
    end
  end
end
