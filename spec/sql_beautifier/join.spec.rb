# frozen_string_literal: true

RSpec.describe SqlBeautifier::Join do
  let(:table_registry) { SqlBeautifier::TableRegistry.new(from_content) }

  describe ".parse" do
    let(:from_content) { "users inner join orders on orders.user_id = users.id" }

    context "with an inner join" do
      let(:join) { described_class.parse("inner join orders on orders.user_id = users.id", table_registry: table_registry) }

      it "extracts the keyword" do
        expect(join.keyword).to eq("inner join")
      end

      it "extracts the table reference" do
        expect(join.table_reference.name).to eq("orders")
      end

      it "extracts one condition" do
        expect(join.conditions.length).to eq(1)
      end

      it "parses the condition text" do
        expect(join.conditions.first[1]).to eq("orders.user_id = users.id")
      end
    end

    context "with a cross join" do
      let(:from_content) { "users cross join roles" }
      let(:join) { described_class.parse("cross join roles", table_registry: table_registry) }

      it "extracts the keyword" do
        expect(join.keyword).to eq("cross join")
      end

      it "has no conditions" do
        expect(join.conditions).to be_empty
      end
    end

    context "with multiple ON conditions" do
      let(:from_content) { "users inner join orders on orders.user_id = users.id and orders.active = true" }
      let(:join) { described_class.parse("inner join orders on orders.user_id = users.id and orders.active = true", table_registry: table_registry) }

      it "extracts all conditions" do
        expect(join.conditions.length).to eq(2)
      end
    end

    context "with invalid join text" do
      let(:from_content) { "users" }
      let(:join) { described_class.parse("not_a_join something", table_registry: table_registry) }

      it "returns nil" do
        expect(join).to be_nil
      end
    end
  end

  describe "#render" do
    context "with a single condition" do
      let(:from_content) { "users inner join orders on orders.user_id = users.id" }
      let(:join) { described_class.parse("inner join orders on orders.user_id = users.id", table_registry: table_registry) }
      let(:output) { join.render(continuation_indent: "        ", condition_indent: "            ") }

      it "renders the join line" do
        expect(output).to include("inner join Orders o on orders.user_id = users.id")
      end
    end

    context "with multiple conditions" do
      let(:from_content) { "users inner join orders on orders.user_id = users.id and orders.active = true" }
      let(:join) { described_class.parse("inner join orders on orders.user_id = users.id and orders.active = true", table_registry: table_registry) }
      let(:output) { join.render(continuation_indent: "        ", condition_indent: "            ") }

      it "renders the first condition on the join line" do
        expect(output).to include("inner join Orders o on orders.user_id = users.id")
      end

      it "renders additional conditions on continuation lines" do
        expect(output).to include("            and orders.active = true")
      end
    end

    context "with a cross join" do
      let(:from_content) { "users cross join roles" }
      let(:join) { described_class.parse("cross join roles", table_registry: table_registry) }
      let(:output) { join.render(continuation_indent: "        ", condition_indent: "            ") }

      it "renders without ON clause" do
        expect(output).to eq("        cross join Roles r")
      end
    end

    context "with a trailing comment sentinel on the join table" do
      let(:from_content) { "users inner join orders /*__sqlb_0__*/ on orders.user_id = users.id" }
      let(:join) { described_class.parse("inner join orders /*__sqlb_0__*/ on orders.user_id = users.id", table_registry: table_registry) }
      let(:output) { join.render(continuation_indent: "        ", condition_indent: "            ") }

      it "preserves the sentinel in the rendered output" do
        expect(output).to include("/*__sqlb_0__*/")
      end
    end
  end
end
