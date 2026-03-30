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

    context "with a table not found in the registry" do
      let(:from_content) { "users" }
      let(:join) { described_class.parse("inner join unknown_table on unknown_table.id = users.id", table_registry: table_registry) }

      it "returns nil" do
        expect(join).to be_nil
      end
    end

    ############################################################################
    ## LATERAL Joins
    ############################################################################

    context "with an inner join lateral" do
      let(:from_content) { "users inner join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id" }
      let(:join) { described_class.parse("inner join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id", table_registry: table_registry) }

      it "extracts the keyword" do
        expect(join.keyword).to eq("inner join")
      end

      it "extracts the table reference" do
        expect(join.table_reference.name).to eq("recent_orders")
      end

      it "marks the join as lateral" do
        expect(join.lateral).to be true
      end

      it "extracts one condition" do
        expect(join.conditions.length).to eq(1)
      end
    end

    context "with a left join lateral" do
      let(:from_content) { "users left join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id" }
      let(:join) { described_class.parse("left join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id", table_registry: table_registry) }

      it "extracts the keyword" do
        expect(join.keyword).to eq("left join")
      end

      it "extracts the table reference" do
        expect(join.table_reference.name).to eq("recent_orders")
      end

      it "marks the join as lateral" do
        expect(join.lateral).to be true
      end
    end

    context "with a non-lateral join" do
      let(:join) { described_class.parse("inner join orders on orders.user_id = users.id", table_registry: table_registry) }

      it "does not mark the join as lateral" do
        expect(join.lateral).to be false
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
        expect(output).to match_formatted_text(<<~SQL.chomp)
          ········cross join Roles r
        SQL
      end
    end

    context "with a lateral join and single condition" do
      let(:from_content) { "users inner join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id" }
      let(:join) { described_class.parse("inner join lateral (select id from orders) as recent_orders on recent_orders.user_id = users.id", table_registry: table_registry) }
      let(:output) { join.render(continuation_indent: "        ", condition_indent: "            ") }

      it "includes lateral between the keyword and the table" do
        expect(output).to include("inner join lateral (select id from orders) recent_orders on")
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
