# frozen_string_literal: true

RSpec.describe SqlBeautifier::Clauses::Select do
  describe ".call" do
    let(:output) { described_class.call(value) }

    context "with a single column" do
      let(:value) { "id" }

      it "formats on one line" do
        expect(output).to eq("select  id")
      end
    end

    context "with a star" do
      let(:value) { "*" }

      it "formats on one line" do
        expect(output).to eq("select  *")
      end
    end

    context "with extra whitespace around columns" do
      let(:value) { "  id ,  name ,  email  " }

      it "strips whitespace from each column" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name,
                  email
        SQL
      end
    end

    context "with multiple columns" do
      let(:value) { "id, name, email" }

      it "places each on its own line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name,
                  email
        SQL
      end
    end

    context "with column aliases" do
      let(:value) { "id, name as full_name, email as contact_email" }

      it "keeps each alias with its column" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  name as full_name,
                  email as contact_email
        SQL
      end
    end

    context "with function calls" do
      let(:value) { "id, coalesce(name, 'unknown'), email" }

      it "keeps function arguments together" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  coalesce(name, 'unknown'),
                  email
        SQL
      end
    end

    context "with a subquery column" do
      let(:value) { "id, (select count(*) from orders) as order_count" }

      it "keeps the subquery intact with its alias" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  (select count(*) from orders) as order_count
        SQL
      end
    end

    context "with arithmetic expressions" do
      let(:value) { "id, price * quantity as total, name" }

      it "keeps the expression together" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id,
                  price * quantity as total,
                  name
        SQL
      end
    end

    context "with a column named distinct_count" do
      let(:value) { "distinct_count" }

      it "does not treat the column as a DISTINCT prefix" do
        expect(output).to eq("select  distinct_count")
      end
    end

    context "with multiple columns starting with distinct" do
      let(:value) { "distinct_count, distinct_values" }

      it "formats them as normal columns" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct_count,
                  distinct_values
        SQL
      end
    end

    ############################################################################
    ## DISTINCT
    ############################################################################

    context "with DISTINCT" do
      let(:value) { "distinct id, name, email" }

      it "places distinct on the select line with columns below" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct
                  id,
                  name,
                  email
        SQL
      end
    end

    context "with DISTINCT and a single column" do
      let(:value) { "distinct id" }

      it "places distinct on the select line with the column below" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct
                  id
        SQL
      end
    end

    ############################################################################
    ## DISTINCT ON
    ############################################################################

    context "with DISTINCT ON" do
      let(:value) { "distinct on (user_id) id, name, email" }

      it "places distinct on(...) on the select line with columns below" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct on (user_id)
                  id,
                  name,
                  email
        SQL
      end
    end

    context "with DISTINCT ON with multiple keys" do
      let(:value) { "distinct on (user_id, created_at) id, name" }

      it "keeps the full distinct on(...) on the select line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct on (user_id, created_at)
                  id,
                  name
        SQL
      end
    end

    context "with DISTINCT ON and a single column" do
      let(:value) { "distinct on (user_id) name" }

      it "places the column below the distinct on(...) line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  distinct on (user_id)
                  name
        SQL
      end
    end
  end
end
