# frozen_string_literal: true

RSpec.describe "clause_spacing_mode configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.clause_spacing_mode = config_value
    end
  end

  ############################################################################
  ## clause_spacing_mode: :compact (default)
  ############################################################################

  context "when clause_spacing_mode is :compact (default)" do
    let(:config_value) { :compact }

    context "with a simple single-column single-table query" do
      let(:value) { "SELECT id FROM users" }

      it "uses single newlines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u;
        SQL
      end
    end

    context "with a simple query with WHERE having one condition" do
      let(:value) { "SELECT id FROM users WHERE active = true" }

      it "uses single newlines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          where   active = true;
        SQL
      end
    end

    context "with a simple query with ORDER BY and LIMIT" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25" }

      it "uses single newlines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u
          order by created_at desc
          limit 25;
        SQL
      end
    end

    context "with multiple SELECT columns" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "uses blank lines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true;
        SQL
      end
    end

    context "with multiple WHERE conditions" do
      let(:value) { "SELECT id FROM users WHERE active = true AND verified = true" }

      it "uses blank lines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and verified = true;
        SQL
      end
    end

    context "with JOINs" do
      let(:value) { "SELECT users.id FROM users INNER JOIN orders ON orders.user_id = users.id" }

      it "uses blank lines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  u.id

          from    Users u
                  inner join Orders o on o.user_id = u.id;
        SQL
      end
    end

    context "with GROUP BY" do
      let(:value) { "SELECT department, count(*) FROM users GROUP BY department" }

      it "uses blank lines between clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  department,
                  count(*)

          from    Users u

          group by department;
        SQL
      end
    end
  end

  ############################################################################
  ## clause_spacing_mode: :spacious
  ############################################################################

  context "when clause_spacing_mode is :spacious" do
    let(:config_value) { :spacious }

    context "with a simple single-column single-table query" do
      let(:value) { "SELECT id FROM users" }

      it "uses blank lines between all clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u;
        SQL
      end
    end

    context "with a simple query with WHERE having one condition" do
      let(:value) { "SELECT id FROM users WHERE active = true" }

      it "uses blank lines between all clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u

          where   active = true;
        SQL
      end
    end

    context "with a simple query with ORDER BY and LIMIT" do
      let(:value) { "SELECT id FROM users ORDER BY created_at DESC LIMIT 25" }

      it "uses blank lines between all clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id

          from    Users u

          order by created_at desc

          limit 25;
        SQL
      end
    end

    context "with multiple SELECT columns" do
      let(:value) { "SELECT id, name FROM users WHERE active = true" }

      it "uses blank lines between all clauses" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name

          from    Users u

          where   active = true;
        SQL
      end
    end
  end
end
