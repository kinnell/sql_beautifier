# frozen_string_literal: true

RSpec.describe "indent_spaces configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.indent_spaces = config_value
    end
  end

  ############################################################################
  ## indent_spaces: 4 (default)
  ############################################################################

  context "when indent_spaces is 4 (default)" do
    let(:config_value) { 4 }

    context "with a subquery in WHERE" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "indents the subquery body by 4 spaces from the base indent" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                  );
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "indents the CTE body by 4 spaces" do
        expect(output).to match_formatted_text(<<~SQL)
          with Active as (
          ····select  id
          ····from    Users u
          ····where   active = true
          )

          select  *
          from    Active a;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "indents the body by 4 spaces" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          );
        SQL
      end
    end

    context "with a nested subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE product_id IN (SELECT id FROM products WHERE active = true))" }

      it "increases indentation at each nesting level" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
                      select  user_id
                      from    Orders o
                      where   product_id in (
                                  select  id
                                  from    Products p
                                  where   active = true
                              )
                  );
        SQL
      end
    end
  end

  ############################################################################
  ## indent_spaces: 2
  ############################################################################

  context "when indent_spaces is 2" do
    let(:config_value) { 2 }

    context "with a subquery in WHERE" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders)" }

      it "indents the subquery body by 2 spaces from the base indent" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
          ··········select  user_id
          ··········from    Orders o
          ········);
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "indents the CTE body by 2 spaces" do
        expect(output).to match_formatted_text(<<~SQL)
          with Active as (
          ··select  id
          ··from    Users u
          ··where   active = true
          )

          select  *
          from    Active a;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "indents the body by 2 spaces" do
        expect(output).to match_formatted_text(<<~SQL)
          create temp table Foo as (
            select  id
            from    Users u
          );
        SQL
      end
    end

    context "with a nested subquery" do
      let(:value) { "SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE product_id IN (SELECT id FROM products WHERE active = true))" }

      it "increases indentation at each nesting level with narrower steps" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   id in (
          ··········select  user_id
          ··········from    Orders o
          ··········where   product_id in (
          ····················select  id
          ····················from    Products p
          ····················where   active = true
          ··················)
          ········);
        SQL
      end
    end
  end
end
