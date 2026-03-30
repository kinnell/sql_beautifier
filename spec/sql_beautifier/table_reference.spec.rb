# frozen_string_literal: true

RSpec.describe SqlBeautifier::TableReference do
  describe ".parse" do
    context "with a simple table name" do
      let(:reference) { described_class.parse("users") }

      it "extracts the table name" do
        expect(reference.name).to eq("users")
      end

      it "has no explicit alias" do
        expect(reference.explicit_alias).to be_nil
      end
    end

    context "with an explicit alias" do
      let(:reference) { described_class.parse("users u") }

      it "extracts the table name" do
        expect(reference.name).to eq("users")
      end

      it "extracts the explicit alias" do
        expect(reference.explicit_alias).to eq("u")
      end
    end

    context "with an AS alias" do
      let(:reference) { described_class.parse("users as u") }

      it "extracts the alias after AS" do
        expect(reference.explicit_alias).to eq("u")
      end
    end

    context "with ON conditions in the segment" do
      let(:reference) { described_class.parse("orders on orders.user_id = users.id") }

      it "extracts only the table name before ON" do
        expect(reference.name).to eq("orders")
      end
    end

    context "with an alias and ON conditions" do
      let(:reference) { described_class.parse("orders o on orders.user_id = users.id") }

      it "extracts the table name" do
        expect(reference.name).to eq("orders")
      end

      it "extracts the alias" do
        expect(reference.explicit_alias).to eq("o")
      end
    end

    context "with an empty string" do
      let(:reference) { described_class.parse("  ") }

      it "returns nil" do
        expect(reference).to be_nil
      end
    end

    ############################################################################
    ## Derived Tables
    ############################################################################

    context "with a derived table using AS alias" do
      let(:reference) { described_class.parse("(select id from users) as subq") }

      it "extracts the alias as the name" do
        expect(reference.name).to eq("subq")
      end

      it "stores the explicit alias" do
        expect(reference.explicit_alias).to eq("subq")
      end

      it "stores the derived table expression" do
        expect(reference.derived_table_expression).to eq("(select id from users)")
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end

    context "with a derived table using bare alias" do
      let(:reference) { described_class.parse("(select id from users) subq") }

      it "extracts the alias as the name" do
        expect(reference.name).to eq("subq")
      end

      it "stores the explicit alias" do
        expect(reference.explicit_alias).to eq("subq")
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end

    context "with a derived table containing joins" do
      let(:reference) { described_class.parse("(select id from users inner join orders on orders.user_id = users.id) as subq") }

      it "preserves the full expression including joins" do
        expect(reference.derived_table_expression).to eq("(select id from users inner join orders on orders.user_id = users.id)")
      end

      it "extracts the alias" do
        expect(reference.explicit_alias).to eq("subq")
      end
    end

    context "with a derived table without alias" do
      let(:reference) { described_class.parse("(select id from users)") }

      it "stores the expression as the name" do
        expect(reference.name).to eq("(select id from users)")
      end

      it "has no explicit alias" do
        expect(reference.explicit_alias).to be_nil
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end

    ############################################################################
    ## LATERAL Derived Tables
    ############################################################################

    context "with a lateral derived table using AS alias" do
      let(:reference) { described_class.parse("lateral (select id from users) as subq") }

      it "extracts the alias as the name" do
        expect(reference.name).to eq("subq")
      end

      it "stores the explicit alias" do
        expect(reference.explicit_alias).to eq("subq")
      end

      it "stores the derived table expression without lateral" do
        expect(reference.derived_table_expression).to eq("(select id from users)")
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end

    context "with a lateral derived table using bare alias" do
      let(:reference) { described_class.parse("lateral (select id from users) subq") }

      it "extracts the alias as the name" do
        expect(reference.name).to eq("subq")
      end

      it "stores the explicit alias" do
        expect(reference.explicit_alias).to eq("subq")
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end

    context "with a lateral derived table and ON conditions" do
      let(:reference) { described_class.parse("lateral (select id from orders) as recent on recent.user_id = users.id") }

      it "extracts the alias as the name" do
        expect(reference.name).to eq("recent")
      end

      it "identifies as a derived table" do
        expect(reference).to be_derived_table
      end
    end
  end

  ############################################################################
  ## .strip_lateral_prefix
  ############################################################################

  describe ".strip_lateral_prefix" do
    context "with a lateral prefix" do
      let(:text) { "lateral (select id from users)" }
      let(:result) { described_class.strip_lateral_prefix(text) }

      it "returns the text without the lateral prefix" do
        expect(result[0]).to eq("(select id from users)")
      end

      it "returns true for the lateral flag" do
        expect(result[1]).to be true
      end
    end

    context "without a lateral prefix" do
      let(:text) { "(select id from users)" }
      let(:result) { described_class.strip_lateral_prefix(text) }

      it "returns the text unchanged" do
        expect(result[0]).to eq("(select id from users)")
      end

      it "returns false for the lateral flag" do
        expect(result[1]).to be false
      end
    end

    context "with leading whitespace before lateral" do
      let(:text) { "  lateral (select id from users)" }
      let(:result) { described_class.strip_lateral_prefix(text) }

      it "strips whitespace and removes lateral" do
        expect(result[0]).to eq("(select id from users)")
      end

      it "returns true for the lateral flag" do
        expect(result[1]).to be true
      end
    end
  end

  describe "#formatted_name" do
    let(:reference) { described_class.new(name: "user_roles") }

    it "returns the PascalCase formatted name" do
      expect(reference.formatted_name).to eq("User_Roles")
    end
  end

  describe "#alias_name" do
    context "with an explicit alias" do
      let(:reference) { described_class.new(name: "users", explicit_alias: "u") }

      it "returns the explicit alias" do
        expect(reference.alias_name).to eq("u")
      end
    end

    context "with an assigned alias" do
      let(:reference) { described_class.new(name: "users", assigned_alias: "u") }

      it "returns the assigned alias" do
        expect(reference.alias_name).to eq("u")
      end
    end

    context "with both explicit and assigned aliases" do
      let(:reference) { described_class.new(name: "users", explicit_alias: "usr", assigned_alias: "u") }

      it "prefers the explicit alias" do
        expect(reference.alias_name).to eq("usr")
      end
    end

    context "with no aliases" do
      let(:reference) { described_class.new(name: "users") }

      it "returns nil" do
        expect(reference.alias_name).to be_nil
      end
    end
  end

  describe "#render" do
    context "with an alias" do
      let(:reference) { described_class.new(name: "users", assigned_alias: "u") }

      it "renders formatted name with alias" do
        expect(reference.render).to eq("Users u")
      end
    end

    context "without an alias" do
      let(:reference) { described_class.new(name: "users") }

      it "renders only the formatted name" do
        expect(reference.render).to eq("Users")
      end
    end

    context "with trailing sentinels" do
      let(:reference) { described_class.new(name: "users", assigned_alias: "u") }

      it "appends sentinels after the alias" do
        expect(reference.render(trailing_sentinels: ["/*__sqlb_0__*/"])).to eq("Users u /*__sqlb_0__*/")
      end
    end

    context "with an underscore-separated table name" do
      let(:reference) { described_class.new(name: "user_roles", assigned_alias: "ur") }

      it "PascalCases the table name" do
        expect(reference.render).to eq("User_Roles ur")
      end
    end

    context "with a derived table expression and alias" do
      let(:reference) { described_class.new(name: "subq", explicit_alias: "subq", derived_table_expression: "(select id from users)") }

      it "renders the raw expression with alias" do
        expect(reference.render).to eq("(select id from users) subq")
      end
    end

    context "with a derived table expression without alias" do
      let(:reference) { described_class.new(name: "(select id from users)", derived_table_expression: "(select id from users)") }

      it "renders just the raw expression" do
        expect(reference.render).to eq("(select id from users)")
      end
    end
  end
end
