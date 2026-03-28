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
  end
end
