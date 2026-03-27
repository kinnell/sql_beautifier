# frozen_string_literal: true

RSpec.describe SqlBeautifier::Normalizer do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with nil" do
      let(:value) { nil }

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

    context "with a whitespace-only string" do
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

    context "when the value has whitespace inside a string literal" do
      let(:value) { "SELECT * FROM users WHERE bio = 'Hello   World'" }

      it "preserves whitespace inside the string literal" do
        expect(output).to eq("select * from users where bio = 'Hello   World'")
      end
    end

    context "when the value has an unclosed double-quoted identifier" do
      let(:value) { 'SELECT "broken FROM users' }

      it "treats the opening quote as a regular character" do
        expect(output).to eq('select "broken from users')
      end
    end

    context "when the value has tab characters" do
      let(:value) { "SELECT\tid\tFROM\tusers" }

      it "collapses tabs to single spaces" do
        expect(output).to eq("select id from users")
      end
    end

    context "when the value has newline characters" do
      let(:value) { "SELECT id\nFROM users\nWHERE active = true" }

      it "collapses newlines to single spaces" do
        expect(output).to eq("select id from users where active = true")
      end
    end

    context "when the value has an unclosed single-quoted string" do
      let(:value) { "SELECT * FROM users WHERE name = 'broken" }

      it "preserves the content through end of input" do
        expect(output).to eq("select * from users where name = 'broken")
      end
    end

    context "when the value has a safe double-quoted identifier" do
      let(:value) { 'SELECT "Users" FROM "Users"' }

      it "removes the quotes and lowercases" do
        expect(output).to eq("select users from users")
      end
    end

    context "when the value has a double-quoted identifier requiring quoting" do
      let(:value) { 'SELECT "has space" FROM users' }

      it "preserves double quotes around the lowercased identifier" do
        expect(output).to eq('select "has space" from users')
      end
    end

    context "when the value has a double-quoted identifier with digits" do
      let(:value) { 'SELECT "Column1" FROM users' }

      it "removes quotes from a safe lowercased identifier" do
        expect(output).to eq("select column1 from users")
      end
    end

    context "when the value has adjacent single-quoted strings with no space" do
      let(:value) { "SELECT 'A''B' FROM users" }

      it "preserves escaped quotes inside the string" do
        expect(output).to eq("select 'A''B' from users")
      end
    end

    ############################################################################
    ## Semicolon Stripping
    ############################################################################

    context "with a trailing semicolon" do
      let(:value) { "SELECT id FROM users;" }

      it "removes the trailing semicolon" do
        expect(output).to eq("select id from users")
      end
    end

    context "with a trailing semicolon and whitespace" do
      let(:value) { "SELECT id FROM users;  \n  " }

      it "removes the trailing semicolon and whitespace" do
        expect(output).to eq("select id from users")
      end
    end

    context "with a trailing semicolon before a line comment" do
      let(:value) { "SELECT 1; -- done" }

      it "removes the semicolon after comment stripping" do
        expect(output).to eq("select 1")
      end
    end

    context "with multiple trailing semicolons" do
      let(:value) { "SELECT 1;;" }

      it "removes only the last semicolon" do
        expect(output).to eq("select 1;")
      end
    end

    context "with a semicolon inside a string literal" do
      let(:value) { "SELECT * FROM users WHERE name = 'test;value'" }

      it "preserves the semicolon inside the string" do
        expect(output).to eq("select * from users where name = 'test;value'")
      end
    end

    context "with no semicolon" do
      let(:value) { "SELECT 1" }

      it "returns unchanged" do
        expect(output).to eq("select 1")
      end
    end

    ############################################################################
    ## Comment Stripping
    ############################################################################

    context "with a -- line comment" do
      let(:value) { "SELECT id -- get the id\nFROM users" }

      it "removes the line comment" do
        expect(output).to eq("select id from users")
      end
    end

    context "with a -- comment at end of query" do
      let(:value) { "SELECT id FROM users -- done" }

      it "removes the trailing comment" do
        expect(output).to eq("select id from users")
      end
    end

    context "with -- inside a string literal" do
      let(:value) { "SELECT * FROM users WHERE name = 'test--value'" }

      it "preserves -- inside the string" do
        expect(output).to eq("select * from users where name = 'test--value'")
      end
    end

    context "with -- inside a double-quoted identifier" do
      let(:value) { 'SELECT "User--Name" FROM users' }

      it "preserves -- inside the identifier" do
        expect(output).to eq('select "user--name" from users')
      end
    end

    context "with a /* */ block comment" do
      let(:value) { "SELECT /* columns */ id FROM users" }

      it "removes the block comment" do
        expect(output).to eq("select id from users")
      end
    end

    context "with a /* */ block comment between tokens" do
      let(:value) { "SELECT/*columns*/id FROM users" }

      it "preserves token separation after stripping the comment" do
        expect(output).to eq("select id from users")
      end
    end

    context "with a /* */ block comment spanning content" do
      let(:value) { "SELECT id /* , name, email */ FROM users" }

      it "removes the spanning block comment" do
        expect(output).to eq("select id from users")
      end
    end

    context "with /* */ inside a string literal" do
      let(:value) { "SELECT * FROM users WHERE name = 'test/**/value'" }

      it "preserves /* */ inside the string" do
        expect(output).to eq("select * from users where name = 'test/**/value'")
      end
    end

    context "with /* */ inside a double-quoted identifier" do
      let(:value) { 'SELECT "Cost/*Center*/Code" FROM users' }

      it "preserves /* */ inside the identifier" do
        expect(output).to eq('select "cost/*center*/code" from users')
      end
    end

    context "with multiple comments" do
      let(:value) { "SELECT /* a */ id -- get id\nFROM users" }

      it "strips all comments" do
        expect(output).to eq("select id from users")
      end
    end

    context "with comment-only input" do
      let(:value) { "-- just a comment" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with mixed -- and /* */ comments" do
      let(:value) { "/* header */ SELECT id -- inline\nFROM /* source */ users" }

      it "strips all comments" do
        expect(output).to eq("select id from users")
      end
    end
  end
end
