# frozen_string_literal: true

RSpec.describe SqlBeautifier::StatementAssembler do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single statement" do
      let(:value) { "SELECT id FROM users" }

      it "formats the statement" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end

      it "ends with a semicolon terminator" do
        expect(output).to end_with(";\n")
      end
    end

    context "with two semicolon-separated statements" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      it "formats each statement" do
        expect(output).to include("from    Constituents c")
        expect(output).to include("from    Departments d")
      end

      it "joins statements with a semicolon separator" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c;

          select  id
          from    Departments d;
        SQL
      end
    end

    context "with three statements" do
      let(:value) { "SELECT id FROM users; SELECT id FROM orders; SELECT id FROM products" }

      it "joins all statements with semicolon separators" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;

          select  id
          from    Orders o;

          select  id
          from    Products p;
        SQL
      end
    end

    context "when all statements format to nil" do
      let(:value) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with :trailing_semicolon set to false" do
      let(:value) { "SELECT id FROM constituents; SELECT id FROM departments" }

      before do
        SqlBeautifier.configure do |config|
          config.trailing_semicolon = false
        end
      end

      it "joins statements without semicolons" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Constituents c

          select  id
          from    Departments d
        SQL
      end
    end

    context "with :trailing_semicolon set to false and a single statement" do
      let(:value) { "SELECT id FROM users" }

      before do
        SqlBeautifier.configure do |config|
          config.trailing_semicolon = false
        end
      end

      it "ends with a newline without a semicolon" do
        expect(output).to end_with("u\n")
        expect(output).not_to include(";")
      end
    end
  end
end
