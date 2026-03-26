# frozen_string_literal: true

RSpec.describe SqlBeautifier::Normalizer do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "when the value is nil" do
      let(:value) { nil }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is an empty string" do
      let(:value) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value is a whitespace-only string" do
      let(:value) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "when the value has extra whitespace" do
      let(:value) { "  SELECT   id ,  name   FROM   users  " }

      it "collapses to single spaces" do
        expect(output).to eq("select id , name from users")
      end
    end

    context "when the value has mixed case keywords" do
      let(:value) { "SELECT Id, Name FROM Users" }

      it "lowercases everything" do
        expect(output).to eq("select id, name from users")
      end
    end

    context "when the value has a single-quoted string" do
      let(:value) { "SELECT * FROM users WHERE name = 'John DOE'" }

      it "preserves string literal case" do
        expect(output).to eq("select * from users where name = 'John DOE'")
      end
    end

    context "when the value has an escaped single quote" do
      let(:value) { "SELECT * FROM users WHERE name = 'O''Brien'" }

      it "preserves escaped quotes" do
        expect(output).to eq("select * from users where name = 'O''Brien'")
      end
    end

    context "when the value has a double-quoted identifier" do
      let(:value) { 'SELECT "User_Id", "Full_Name" FROM "Users"' }

      it "strips delimiters and lowercases contents" do
        expect(output).to eq("select user_id, full_name from users")
      end
    end

    context "when the value has a double-quoted identifier with spaces" do
      let(:value) { 'SELECT "Full Name" FROM users' }

      it "preserves delimiters and lowercases contents" do
        expect(output).to eq('select "full name" from users')
      end
    end

    context "when the value has an escaped double quote inside an identifier" do
      let(:value) { 'SELECT "has""quotes"" inside" FROM users' }

      it "preserves delimiters for identifiers containing double quotes" do
        expect(output).to eq('select "has""quotes"" inside" from users')
      end
    end

    context "when the value has multiple string literals" do
      let(:value) { "SELECT * FROM users WHERE first_name = 'Alice' AND last_name = 'O''Brien' AND status = 'Active'" }

      it "preserves case inside all string literals" do
        expect(output).to eq("select * from users where first_name = 'Alice' and last_name = 'O''Brien' and status = 'Active'")
      end
    end

    context "when the value has adjacent string literals" do
      let(:value) { "SELECT * FROM users WHERE name IN ('Alice', 'BOB', 'Charlie')" }

      it "preserves case inside each string" do
        expect(output).to eq("select * from users where name in ('Alice', 'BOB', 'Charlie')")
      end
    end

    context "when the value has an unclosed double-quoted identifier" do
      let(:value) { 'SELECT "broken FROM users' }

      it "treats the opening quote as a regular character" do
        expect(output).to eq('select "broken from users')
      end
    end
  end
end
