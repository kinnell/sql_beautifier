# frozen_string_literal: true

RSpec.describe "keyword_case configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.keyword_case = config_value
    end
  end

  ############################################################################
  ## keyword_case: :lower (default)
  ############################################################################

  context "when keyword_case is :lower (default)" do
    let(:config_value) { :lower }

    context "with a simple query" do
      let(:value) { "SELECT id FROM users" }

      it "lowercases all keywords" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with all clause types" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department HAVING count(*) > 5 ORDER BY name LIMIT 10" }

      it "lowercases all clause keywords" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true

          group by department

          having  count(*) > 5

          order by name

          limit 10;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "lowercases clause keywords" do
        expect(output).to eq(<<~SQL)
          select  u.id

          from    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with WHERE conditions" do
      let(:value) { "SELECT id FROM users WHERE active = true AND verified = true" }

      it "lowercases conjunctions" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and verified = true;
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "lowercases CTE keywords" do
        expect(output).to eq(<<~SQL)
          with    active as (
                      select  id
                      from    Users u
                      where   active = true
                  )

          select  *
          from    Active a;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "lowercases preamble keywords" do
        expect(output).to eq(<<~SQL)
          create temp table Foo as (
              select  id
              from    Users u
          );
        SQL
      end
    end

    context "with DISTINCT" do
      let(:value) { "SELECT DISTINCT name FROM users" }

      it "lowercases the distinct keyword" do
        expect(output).to eq(<<~SQL)
          select  distinct
                  name

          from    Users u;
        SQL
      end
    end
  end

  ############################################################################
  ## keyword_case: :upper
  ############################################################################

  context "when keyword_case is :upper" do
    let(:config_value) { :upper }

    context "with a simple query" do
      let(:value) { "SELECT id FROM users" }

      it "uppercases clause keywords" do
        expect(output).to eq(<<~SQL)
          SELECT  id
          FROM    Users u;
        SQL
      end
    end

    context "with all clause types" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department HAVING count(*) > 5 ORDER BY name LIMIT 10" }

      it "uppercases all clause keywords" do
        expect(output).to eq(<<~SQL)
          SELECT  id

          FROM    Users u

          WHERE   active = true

          GROUP BY department

          HAVING  count(*) > 5

          ORDER BY name

          LIMIT 10;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "uppercases clause keywords while join keywords remain lowercase" do
        expect(output).to eq(<<~SQL)
          SELECT  u.id

          FROM    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with WHERE conditions" do
      let(:value) { "SELECT id FROM users WHERE active = true AND verified = true" }

      it "uppercases clause keywords while conjunctions remain lowercase" do
        expect(output).to eq(<<~SQL)
          SELECT  id

          FROM    Users u

          WHERE   active = true
                  and verified = true;
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "uppercases CTE keywords" do
        expect(output).to eq(<<~SQL)
          WITH    active AS (
                      SELECT  id
                      FROM    Users u
                      WHERE   active = true
                  )

          SELECT  *
          FROM    Active a;
        SQL
      end
    end

    context "with a CREATE TABLE AS" do
      let(:value) { "CREATE TEMP TABLE foo AS (SELECT id FROM users)" }

      it "uppercases preamble keywords" do
        expect(output).to eq(<<~SQL)
          CREATE TEMP TABLE Foo AS (
              SELECT  id
              FROM    Users u
          );
        SQL
      end
    end

    context "with DISTINCT" do
      let(:value) { "SELECT DISTINCT name FROM users" }

      it "uppercases clause keywords while distinct remains lowercase from normalizer" do
        expect(output).to eq(<<~SQL)
          SELECT  distinct
                  name

          FROM    Users u;
        SQL
      end
    end
  end
end
