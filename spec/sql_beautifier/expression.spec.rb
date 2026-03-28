# frozen_string_literal: true

RSpec.describe SqlBeautifier::Expression do
  describe ".parse" do
    context "with a simple column reference" do
      let(:expression) { described_class.parse("users.id") }

      it "stores the definition" do
        expect(expression.definition).to eq("users.id")
      end

      it "has no alias" do
        expect(expression.alias_name).to be_nil
      end
    end

    context "with an aliased column" do
      let(:expression) { described_class.parse("users.id as user_id") }

      it "extracts the definition" do
        expect(expression.definition).to eq("users.id")
      end

      it "extracts the alias" do
        expect(expression.alias_name).to eq("user_id")
      end
    end

    context "with a function call" do
      let(:expression) { described_class.parse("count(*)") }

      it "stores the full function as the definition" do
        expect(expression.definition).to eq("count(*)")
      end

      it "has no alias" do
        expect(expression.alias_name).to be_nil
      end
    end

    context "with a function call with AS alias" do
      let(:expression) { described_class.parse("nullif(x, 0) as safe_x") }

      it "extracts the function as definition" do
        expect(expression.definition).to eq("nullif(x, 0)")
      end

      it "extracts the alias" do
        expect(expression.alias_name).to eq("safe_x")
      end
    end

    context "with AS inside a function call (not top-level)" do
      let(:expression) { described_class.parse("cast(x as integer)") }

      it "treats the entire text as the definition" do
        expect(expression.definition).to eq("cast(x as integer)")
      end

      it "has no alias" do
        expect(expression.alias_name).to be_nil
      end
    end

    context "with a string literal containing as" do
      let(:expression) { described_class.parse("'as_test'") }

      it "treats the entire text as the definition" do
        expect(expression.definition).to eq("'as_test'")
      end

      it "has no alias" do
        expect(expression.alias_name).to be_nil
      end
    end

    context "with whitespace" do
      let(:expression) { described_class.parse("  users.name  ") }

      it "strips the definition" do
        expect(expression.definition).to eq("users.name")
      end
    end

    context "with a column name containing 'as' as a substring" do
      let(:expression) { described_class.parse("base_amount") }

      it "treats the entire text as the definition" do
        expect(expression.definition).to eq("base_amount")
      end

      it "has no alias" do
        expect(expression.alias_name).to be_nil
      end
    end

    context "with a CASE expression aliased" do
      let(:expression) { described_class.parse("case when x > 0 then 'positive' else 'negative' end as sign") }

      it "extracts the CASE as definition" do
        expect(expression.definition).to eq("case when x > 0 then 'positive' else 'negative' end")
      end

      it "extracts the alias" do
        expect(expression.alias_name).to eq("sign")
      end
    end
  end

  describe "#render" do
    context "without an alias" do
      let(:expression) { described_class.new(definition: "users.id") }

      it "renders the definition" do
        expect(expression.render).to eq("users.id")
      end
    end

    context "with an alias" do
      let(:expression) { described_class.new(definition: "users.id", alias_name: "user_id") }

      it "renders definition as alias" do
        expect(expression.render).to eq("users.id as user_id")
      end
    end
  end
end
