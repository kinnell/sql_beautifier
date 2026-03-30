# frozen_string_literal: true

RSpec.describe "keyword_column_width configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.keyword_column_width = config_value
    end
  end

  ############################################################################
  ## keyword_column_width: 8 (default)
  ############################################################################

  context "when keyword_column_width is 8 (default)" do
    let(:config_value) { 8 }

    context "with a multi-clause query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "pads single-word keywords to 8 characters" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true;
        SQL
      end
    end

    context "with all clause types" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department HAVING count(*) > 5 ORDER BY name LIMIT 10" }

      it "pads keywords consistently and uses single space for multi-word keywords" do
        expect(output).to match_formatted_text(<<~SQL)
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

      it "uses 8-character continuation indent for joins" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id

          from    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end
  end

  ############################################################################
  ## keyword_column_width: 10
  ############################################################################

  context "when keyword_column_width is 10" do
    let(:config_value) { 10 }

    context "with a multi-clause query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "pads single-word keywords to 10 characters" do
        expect(output).to match_formatted_text(<<~SQL)
          select    id,
                    name

          from      Users u

          where     active = true;
        SQL
      end
    end

    context "with all clause types" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department HAVING count(*) > 5 ORDER BY name LIMIT 10" }

      it "widens padding for all padded keywords" do
        expect(output).to match_formatted_text(<<~SQL)
          select    id

          from      Users u

          where     active = true

          group by  department

          having    count(*) > 5

          order by  name

          limit 10;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "uses 10-character continuation indent for joins" do
        expect(output).to match_formatted_text(<<~SQL)
          select    u.id

          from      Users u
                    inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with a CTE" do
      let(:value) { "WITH active AS (SELECT id FROM users WHERE active = true) SELECT * FROM active" }

      it "widens the CTE body indentation" do
        expect(output).to match_formatted_text(<<~SQL)
          with      active as (
                        select    id
                        from      Users u
                        where     active = true
                    )

          select    *
          from      Active a;
        SQL
      end
    end
  end

  ############################################################################
  ## keyword_column_width: 12
  ############################################################################

  context "when keyword_column_width is 12" do
    let(:config_value) { 12 }

    context "with a multi-clause query" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "pads single-word keywords to 12 characters" do
        expect(output).to match_formatted_text(<<~SQL)
          select      id,
                      name

          from        Users u

          where       active = true;
        SQL
      end
    end

    context "with all clause types" do
      let(:value) { "SELECT id FROM users WHERE active = true GROUP BY department HAVING count(*) > 5 ORDER BY name LIMIT 10" }

      it "widens padding for all padded keywords" do
        expect(output).to match_formatted_text(<<~SQL)
          select      id

          from        Users u

          where       active = true

          group by    department

          having      count(*) > 5

          order by    name

          limit 10;
        SQL
      end
    end
  end
end
