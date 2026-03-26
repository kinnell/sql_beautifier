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
  end

  ############################################################################
  ## Parenthesis Helpers
  ############################################################################

  describe ".top_level?" do
    let(:output) { described_class.top_level?(value, position) }

    context "when the value is at depth 0" do
      let(:value) { "a and b" }
      let(:position) { 2 }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "when the value is inside parentheses" do
      let(:value) { "(a and b)" }
      let(:position) { 3 }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "when the value is inside a string literal" do
      let(:value) { "name = 'select from where'" }
      let(:position) { 8 }

      it "returns false for positions inside the string" do
        select_position = value.index("select")
        expect(described_class.top_level?(value, select_position)).to be false
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
  end
end
