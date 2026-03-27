# frozen_string_literal: true

RSpec.describe SqlBeautifier::Tokenizer do
  ############################################################################
  ## Comma Splitting
  ############################################################################

  describe ".split_by_top_level_commas" do
    let(:output) { described_class.split_by_top_level_commas(value) }

    context "when the value has simple columns" do
      let(:value) { "id, name, email" }

      it "splits into three parts" do
        expect(output).to eq(%w[id name email])
      end
    end

    context "when the value has commas inside parentheses" do
      let(:value) { "coalesce(a, b), name" }

      it "does not split on nested commas" do
        expect(output).to eq(["coalesce(a, b)", "name"])
      end
    end

    context "when the value has commas inside strings" do
      let(:value) { "'hello, world', name" }

      it "does not split on string commas" do
        expect(output).to eq(["'hello, world'", "name"])
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "returns an empty array" do
        expect(output).to eq([])
      end
    end

    context "when the value has no commas" do
      let(:value) { "id" }

      it "returns the single value" do
        expect(output).to eq(["id"])
      end
    end

    context "when the value has a comma inside a quoted identifier" do
      let(:value) { '"user,name", id' }

      it "does not split on the comma inside the quoted identifier" do
        expect(output).to eq(['"user,name"', "id"])
      end
    end

    context "when the value has deeply nested parentheses" do
      let(:value) { "outer(inner(a, b), c), d" }

      it "does not split on commas inside nested parentheses" do
        expect(output).to eq(["outer(inner(a, b), c)", "d"])
      end
    end

    context "when the value has escaped single quotes inside strings" do
      let(:value) { "'it''s, complicated', name" }

      it "does not split on commas inside escaped-quote strings" do
        expect(output).to eq(["'it''s, complicated'", "name"])
      end
    end

    context "when the value has escaped double quotes inside a quoted identifier" do
      let(:value) { '"col""name", id' }

      it "does not split on the comma inside the quoted identifier" do
        expect(output).to eq(['"col""name"', "id"])
      end
    end
  end

  ############################################################################
  ## Parenthesis Helpers
  ############################################################################

  describe ".top_level?" do
    let(:output) { described_class.top_level?(value, position) }

    context "when at depth 0" do
      let(:value) { "a and b" }
      let(:position) { 2 }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "when inside parentheses" do
      let(:value) { "(a and b)" }
      let(:position) { 3 }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when inside a string literal" do
      let(:value) { "name = 'select from where'" }
      let(:position) { 8 }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when inside a quoted identifier" do
      let(:value) { '"and" and b' }
      let(:position) { 1 }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when the value follows a quoted identifier" do
      let(:value) { '"and" and b' }
      let(:position) { 6 }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "when at position 0" do
      let(:value) { "select id from users" }
      let(:position) { 0 }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "when inside nested parentheses" do
      let(:value) { "((a and b))" }
      let(:position) { 3 }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when after escaped single quotes" do
      let(:value) { "name = 'O''Brien' and active = true" }
      let(:position) { 19 }

      it "returns true" do
        expect(output).to be true
      end
    end
  end

  ############################################################################
  ## Clause Splitting
  ############################################################################

  describe ".split_into_clauses" do
    let(:output) { described_class.split_into_clauses(value) }

    context "with a standard multi-clause query" do
      let(:value) { "select id, name from users where active = true order by name" }

      it "extracts :select clause" do
        expect(output[:select]).to eq("id, name")
      end

      it "extracts :from clause" do
        expect(output[:from]).to start_with("users")
      end

      it "extracts :where clause" do
        expect(output[:where]).to eq("active = true")
      end

      it "extracts :order_by clause" do
        expect(output[:order_by]).to eq("name")
      end
    end

    context "with a subquery in the where clause" do
      let(:value) { "select id from users where id in (select user_id from orders)" }

      it "does not treat the nested select as a top-level clause" do
        expect(output[:select]).to eq("id")
        expect(output[:from]).to start_with("users")
        expect(output[:where]).to eq("id in (select user_id from orders)")
      end
    end

    context "with a subquery in the select clause" do
      let(:value) { "select id, (select count(*) from orders where orders.user_id = users.id) from users" }

      it "keeps the subquery inside the select clause" do
        expect(output[:select]).to eq("id, (select count(*) from orders where orders.user_id = users.id)")
        expect(output[:from]).to eq("users")
      end
    end

    context "with GROUP BY and HAVING" do
      let(:value) { "select count(*) from users group by status having count(*) > 5" }

      it "extracts :group_by clause" do
        expect(output[:group_by]).to eq("status")
      end

      it "extracts :having clause" do
        expect(output[:having]).to eq("count(*) > 5")
      end
    end

    context "with only a SELECT clause" do
      let(:value) { "select 1" }

      it "extracts only :select" do
        expect(output[:select]).to eq("1")
        expect(output[:from]).to be_nil
      end
    end

    context "with all clause types" do
      let(:value) { "select id from users where active = true group by status having count(*) > 1 order by id limit 10" }

      it "extracts every clause" do
        expect(output[:select]).to eq("id")
        expect(output[:from]).to start_with("users")
        expect(output[:where]).to eq("active = true")
        expect(output[:group_by]).to eq("status")
        expect(output[:having]).to eq("count(*) > 1")
        expect(output[:order_by]).to eq("id")
        expect(output[:limit]).to eq("10")
      end
    end
  end

  ############################################################################
  ## Keyword Finding
  ############################################################################

  describe ".find_top_level_keyword" do
    let(:output) { described_class.find_top_level_keyword(sql, keyword) }

    context "with mixed-case input" do
      let(:sql) { "SELECT id FROM Users WHERE active = TRUE" }

      context "when the keyword is 'select'" do
        let(:keyword) { "select" }

        it "finds the keyword at the correct position" do
          expect(output).to be(0)
        end
      end

      context "when the keyword is 'from'" do
        let(:keyword) { "from" }

        it "finds the keyword at the correct position" do
          expect(output).to be(10)
        end
      end

      context "when the keyword is 'where'" do
        let(:keyword) { "where" }

        it "finds the keyword at the correct position" do
          expect(output).to be(21)
        end
      end
    end

    context "when the keyword appears only inside parentheses" do
      let(:sql) { "select id from users where id in (select user_id from orders)" }
      let(:keyword) { "select" }

      it "does not match nested keywords" do
        expect(output).to be(0)
      end
    end

    context "when the keyword is part of a larger word" do
      let(:sql) { "select selected_at from users" }
      let(:keyword) { "select" }

      it "does not match partial words" do
        expect(output).to be(0)
      end
    end

    context "when a preceding string literal contains a Unicode character whose downcase changes length" do
      let(:sql) { "select * from users where name = 'İ' order by id" }
      let(:keyword) { "order by" }

      it "returns the correct position in the original string" do
        expect(output).to eq(sql.index("order by"))
      end
    end

    context "when the keyword does not exist in the text" do
      let(:sql) { "select id from users" }
      let(:keyword) { "having" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the keyword appears only inside a string literal" do
      let(:sql) { "select * where bio = 'from a galaxy far away'" }
      let(:keyword) { "from" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the keyword appears inside a quoted identifier and at top level" do
      let(:sql) { 'select "from" from users' }
      let(:keyword) { "from" }

      it "finds the top-level occurrence, not the quoted one" do
        expect(output).to eq(14)
      end
    end

    context "with a multi-word keyword" do
      let(:sql) { "select count(*) from users group by status" }
      let(:keyword) { "group by" }

      it "finds the multi-word keyword" do
        expect(output).to eq(27)
      end
    end
  end

  ############################################################################
  ## Condition Splitting
  ############################################################################

  describe ".split_top_level_conditions" do
    let(:output) { described_class.split_top_level_conditions(value) }

    context "with a single condition" do
      let(:value) { "active = true" }

      it "returns one pair with nil conjunction" do
        expect(output).to eq([[nil, "active = true"]])
      end
    end

    context "with AND conditions" do
      let(:value) { "a = 1 and b = 2" }

      it "splits on the top-level and" do
        expect(output).to eq([[nil, "a = 1"], ["and", "b = 2"]])
      end
    end

    context "with OR conditions" do
      let(:value) { "a = 1 or b = 2" }

      it "splits on the top-level or" do
        expect(output).to eq([[nil, "a = 1"], ["or", "b = 2"]])
      end
    end

    context "with mixed AND/OR" do
      let(:value) { "a = 1 and b = 2 or c = 3" }

      it "splits on each conjunction" do
        expect(output).to eq([[nil, "a = 1"], ["and", "b = 2"], ["or", "c = 3"]])
      end
    end

    context "with conditions inside parentheses" do
      let(:value) { "(a = 1 and b = 2) or c = 3" }

      it "does not split inside parentheses" do
        expect(output).to eq([[nil, "(a = 1 and b = 2)"], ["or", "c = 3"]])
      end
    end

    context "with conditions inside a string literal" do
      let(:value) { "name = 'and' and active = true" }

      it "does not split on keywords inside strings" do
        expect(output).to eq([[nil, "name = 'and'"], ["and", "active = true"]])
      end
    end

    context "with three AND conditions" do
      let(:value) { "a = 1 and b = 2 and c = 3" }

      it "splits into three parts" do
        expect(output).to eq([[nil, "a = 1"], ["and", "b = 2"], ["and", "c = 3"]])
      end
    end

    context "with a conjunction keyword inside a quoted identifier" do
      let(:value) { '"and" = 1 and b = 2' }

      it "does not split on the keyword inside the quoted identifier" do
        expect(output).to eq([[nil, '"and" = 1'], ["and", "b = 2"]])
      end
    end

    context "with an escaped single quote near a conjunction" do
      let(:value) { "name = 'O''Brien' and active = true" }

      it "correctly handles the escaped quote boundary" do
        expect(output).to eq([[nil, "name = 'O''Brien'"], ["and", "active = true"]])
      end
    end

    context "when a conjunction directly abuts an opening parenthesis" do
      let(:value) { "a = 1 and(b = 2 or c = 3)" }

      it "treats the parenthesized group as a single condition" do
        expect(output).to eq([[nil, "a = 1"], ["and", "(b = 2 or c = 3)"]])
      end
    end

    context "when multiple conjunctions directly abut opening parentheses" do
      let(:value) { "x = 1 and(a = 2) and(b = 3)" }

      it "splits into three conditions" do
        expect(output).to eq([[nil, "x = 1"], ["and", "(a = 2)"], ["and", "(b = 3)"]])
      end
    end

    context "when a conjunction abuts nested parentheses" do
      let(:value) { "a = 1 or(b = 2 and(c = 3 or d = 4))" }

      it "keeps the nested parentheses as one condition" do
        expect(output).to eq([[nil, "a = 1"], ["or", "(b = 2 and(c = 3 or d = 4))"]])
      end
    end

    context "with a BETWEEN...AND expression" do
      let(:value) { "created_at between '2024-01-01' and '2024-12-31'" }

      it "treats the AND as part of BETWEEN, not a conjunction" do
        expect(output).to eq([[nil, "created_at between '2024-01-01' and '2024-12-31'"]])
      end
    end

    context "with BETWEEN followed by a logical AND" do
      let(:value) { "created_at between '2024-01-01' and '2024-12-31' and active = true" }

      it "skips the BETWEEN AND and splits on the logical AND" do
        expect(output).to eq([[nil, "created_at between '2024-01-01' and '2024-12-31'"], ["and", "active = true"]])
      end
    end

    context "with NOT BETWEEN" do
      let(:value) { "age not between 18 and 65 and active = true" }

      it "skips the NOT BETWEEN AND and splits on the logical AND" do
        expect(output).to eq([[nil, "age not between 18 and 65"], ["and", "active = true"]])
      end
    end

    context "with multiple BETWEEN expressions" do
      let(:value) { "a between 1 and 5 and b between 6 and 10" }

      it "skips both BETWEEN ANDs and splits on the logical AND" do
        expect(output).to eq([[nil, "a between 1 and 5"], ["and", "b between 6 and 10"]])
      end
    end

    context "with BETWEEN inside parentheses" do
      let(:value) { "(a between 1 and 5) and b = 2" }

      it "does not interfere with parenthesized BETWEEN" do
        expect(output).to eq([[nil, "(a between 1 and 5)"], ["and", "b = 2"]])
      end
    end

    context "with a column named between_date" do
      let(:value) { "between_date = '2024-01-01' and active = true" }

      it "does not treat the column name as a BETWEEN keyword" do
        expect(output).to eq([[nil, "between_date = '2024-01-01'"], ["and", "active = true"]])
      end
    end
  end

  ############################################################################
  ## Matching Parenthesis
  ############################################################################

  describe ".find_matching_parenthesis" do
    let(:output) { described_class.find_matching_parenthesis(value, position) }

    context "with simple parentheses" do
      let(:value) { "(a + b)" }
      let(:position) { 0 }

      it "finds the matching close parenthesis" do
        expect(output).to eq(6)
      end
    end

    context "with nested parentheses from the outer position" do
      let(:value) { "(a + (b * c))" }
      let(:position) { 0 }

      it "finds the outermost matching close" do
        expect(output).to eq(12)
      end
    end

    context "with nested parentheses from the inner position" do
      let(:value) { "(a + (b * c))" }
      let(:position) { 5 }

      it "finds the inner matching close" do
        expect(output).to eq(11)
      end
    end

    context "with no matching parenthesis" do
      let(:value) { "(a + b" }
      let(:position) { 0 }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a string literal containing a close paren" do
      let(:value) { "(name = ')')" }
      let(:position) { 0 }

      it "skips the paren inside the string" do
        expect(output).to eq(11)
      end
    end

    context "with a quoted identifier inside parentheses" do
      let(:value) { '("col" = 1)' }
      let(:position) { 0 }

      it "finds the matching close" do
        expect(output).to eq(10)
      end
    end

    context "with escaped double quotes inside a quoted identifier" do
      let(:value) { '("a""b" = 1)' }
      let(:position) { 0 }

      it "finds the matching close" do
        expect(output).to eq(11)
      end
    end

    context "with escaped single quotes inside parentheses" do
      let(:value) { "(name = 'O''Brien')" }
      let(:position) { 0 }

      it "finds the matching close" do
        expect(output).to eq(18)
      end
    end

    context "with empty parentheses" do
      let(:value) { "()" }
      let(:position) { 0 }

      it "finds the matching close" do
        expect(output).to eq(1)
      end
    end
  end

  ############################################################################
  ## Outer Parentheses Detection
  ############################################################################

  describe ".outer_parentheses_wrap_all?" do
    let(:output) { described_class.outer_parentheses_wrap_all?(value) }

    context "when parentheses wrap the entire text" do
      let(:value) { "(a and b)" }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "when parentheses only wrap a prefix" do
      let(:value) { "(a) and b" }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when text does not start with a parenthesis" do
      let(:value) { "a and b" }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "with nested wrapping parentheses" do
      let(:value) { "((a and b))" }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "with surrounding whitespace" do
      let(:value) { "  (a and b)  " }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "with an empty string" do
      let(:value) { "" }

      it "returns false" do
        expect(output).to be false
      end
    end
  end

  ############################################################################
  ## First Clause Position
  ############################################################################

  describe ".first_clause_position" do
    let(:output) { described_class.first_clause_position(value) }

    context "when a clause keyword is at the start" do
      let(:value) { "select id from users" }

      it "returns position 0" do
        expect(output).to eq(0)
      end
    end

    context "when a non-clause prefix exists" do
      let(:value) { "explain select id from users" }

      it "returns the position of the first clause keyword" do
        expect(output).to eq(8)
      end
    end

    context "when no clause keywords exist" do
      let(:value) { "no keywords here" }

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
  end
end
