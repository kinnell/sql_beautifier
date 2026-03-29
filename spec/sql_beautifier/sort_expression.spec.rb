# frozen_string_literal: true

RSpec.describe SqlBeautifier::SortExpression do
  describe ".parse" do
    context "with a simple column" do
      let(:sort_expression) { described_class.parse("name") }

      it "stores the expression" do
        expect(sort_expression.expression).to eq("name")
      end

      it "has no direction" do
        expect(sort_expression.direction).to be_nil
      end

      it "has no nulls modifier" do
        expect(sort_expression.nulls).to be_nil
      end
    end

    context "with ASC direction" do
      let(:sort_expression) { described_class.parse("name asc") }

      it "extracts the expression" do
        expect(sort_expression.expression).to eq("name")
      end

      it "extracts the direction" do
        expect(sort_expression.direction).to eq("asc")
      end
    end

    context "with DESC direction" do
      let(:sort_expression) { described_class.parse("created_at desc") }

      it "extracts the expression" do
        expect(sort_expression.expression).to eq("created_at")
      end

      it "extracts the direction" do
        expect(sort_expression.direction).to eq("desc")
      end
    end

    context "with NULLS FIRST" do
      let(:sort_expression) { described_class.parse("name asc nulls first") }

      it "extracts the expression" do
        expect(sort_expression.expression).to eq("name")
      end

      it "extracts the direction" do
        expect(sort_expression.direction).to eq("asc")
      end

      it "extracts the nulls modifier" do
        expect(sort_expression.nulls).to eq("nulls first")
      end
    end

    context "with NULLS LAST without explicit direction" do
      let(:sort_expression) { described_class.parse("name nulls last") }

      it "extracts the expression" do
        expect(sort_expression.expression).to eq("name")
      end

      it "has no direction" do
        expect(sort_expression.direction).to be_nil
      end

      it "extracts the nulls modifier" do
        expect(sort_expression.nulls).to eq("nulls last")
      end
    end

    context "with a function expression" do
      let(:sort_expression) { described_class.parse("lower(name) desc") }

      it "extracts the function as the expression" do
        expect(sort_expression.expression).to eq("lower(name)")
      end

      it "extracts the direction" do
        expect(sort_expression.direction).to eq("desc")
      end
    end

    context "with whitespace" do
      let(:sort_expression) { described_class.parse("  name  desc  ") }

      it "strips whitespace from the expression" do
        expect(sort_expression.expression).to eq("name")
      end

      it "strips whitespace from the direction" do
        expect(sort_expression.direction).to eq("desc")
      end
    end
  end

  describe "#render" do
    context "with expression only" do
      let(:sort_expression) { described_class.new(expression: "name") }

      it "renders the expression" do
        expect(sort_expression.render).to eq("name")
      end
    end

    context "with direction" do
      let(:sort_expression) { described_class.new(expression: "name", direction: "desc") }

      it "renders expression with direction" do
        expect(sort_expression.render).to eq("name desc")
      end
    end

    context "with direction and nulls" do
      let(:sort_expression) { described_class.new(expression: "name", direction: "asc", nulls: "nulls first") }

      it "renders all parts" do
        expect(sort_expression.render).to eq("name asc nulls first")
      end
    end

    context "with nulls only" do
      let(:sort_expression) { described_class.new(expression: "name", nulls: "nulls last") }

      it "renders expression with nulls" do
        expect(sort_expression.render).to eq("name nulls last")
      end
    end
  end
end
