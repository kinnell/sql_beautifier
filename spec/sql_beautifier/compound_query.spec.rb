# frozen_string_literal: true

RSpec.describe SqlBeautifier::CompoundQuery do
  describe ".parse" do
    context "with no set operators" do
      let(:compound_query) { described_class.parse("select id from users") }

      it "returns nil" do
        expect(compound_query).to be_nil
      end
    end

    context "with a UNION" do
      let(:compound_query) { described_class.parse("select id from users union select id from admins") }

      it "returns a CompoundQuery instance" do
        expect(compound_query).to be_a(described_class)
      end

      it "splits into two segments" do
        expect(compound_query.segments.length).to eq(2)
      end

      it "parses the first segment SQL" do
        expect(compound_query.segments[0][:sql]).to eq("select id from users")
      end

      it "has no operator on the first segment" do
        expect(compound_query.segments[0][:operator]).to be_nil
      end

      it "parses the second segment SQL" do
        expect(compound_query.segments[1][:sql]).to eq("select id from admins")
      end

      it "records the operator on the second segment" do
        expect(compound_query.segments[1][:operator]).to eq("union")
      end
    end

    context "with UNION ALL" do
      let(:compound_query) { described_class.parse("select id from users union all select id from admins") }

      it "matches union all as a single operator" do
        expect(compound_query.segments[1][:operator]).to eq("union all")
      end
    end

    context "with INTERSECT" do
      let(:compound_query) { described_class.parse("select id from users intersect select id from admins") }

      it "records the intersect operator" do
        expect(compound_query.segments[1][:operator]).to eq("intersect")
      end
    end

    context "with EXCEPT" do
      let(:compound_query) { described_class.parse("select id from users except select id from admins") }

      it "records the except operator" do
        expect(compound_query.segments[1][:operator]).to eq("except")
      end
    end

    context "with INTERSECT ALL" do
      let(:compound_query) { described_class.parse("select id from users intersect all select id from admins") }

      it "matches intersect all as a single operator" do
        expect(compound_query.segments[1][:operator]).to eq("intersect all")
      end
    end

    context "with EXCEPT ALL" do
      let(:compound_query) { described_class.parse("select id from users except all select id from admins") }

      it "matches except all as a single operator" do
        expect(compound_query.segments[1][:operator]).to eq("except all")
      end
    end

    context "with three segments and mixed operators" do
      let(:compound_query) { described_class.parse("select id from users union all select id from admins union select id from managers") }

      it "splits into three segments" do
        expect(compound_query.segments.length).to eq(3)
      end

      it "records union all on the second segment" do
        expect(compound_query.segments[1][:operator]).to eq("union all")
      end

      it "records union on the third segment" do
        expect(compound_query.segments[2][:operator]).to eq("union")
      end

      it "parses the third segment SQL" do
        expect(compound_query.segments[2][:sql]).to eq("select id from managers")
      end
    end

    context "with trailing ORDER BY and LIMIT" do
      let(:compound_query) { described_class.parse("select id from users union all select id from admins order by id limit 10") }

      it "extracts trailing clauses from the final segment" do
        expect(compound_query.trailing_clauses).to eq("order by id limit 10")
      end

      it "strips trailing clauses from the final segment SQL" do
        expect(compound_query.segments.last[:sql]).to eq("select id from admins")
      end
    end

    context "with trailing ORDER BY only" do
      let(:compound_query) { described_class.parse("select id from users union select id from admins order by id desc") }

      it "extracts the trailing order by" do
        expect(compound_query.trailing_clauses).to eq("order by id desc")
      end
    end

    context "with a set operator keyword inside a string literal" do
      let(:compound_query) { described_class.parse("select id from users where name = 'union all'") }

      it "returns nil" do
        expect(compound_query).to be_nil
      end
    end

    context "with a set operator keyword inside parentheses" do
      let(:compound_query) { described_class.parse("select id from users where id in (select id from a union all select id from b)") }

      it "returns nil" do
        expect(compound_query).to be_nil
      end
    end

    context "with depth parameter" do
      let(:compound_query) { described_class.parse("select id from users union select id from admins", depth: 12) }

      it "preserves the depth" do
        expect(compound_query.depth).to eq(12)
      end
    end
  end

  describe "#render" do
    context "with a simple UNION" do
      let(:output) { described_class.parse("select id from users union select id from admins").render }

      it "formats each segment independently" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union

          select  id
          from    Admins a
        SQL
      end
    end

    context "with UNION ALL" do
      let(:output) { described_class.parse("select id from users union all select id from admins").render }

      it "places the operator on its own line between blank lines" do
        expect(output).to include("\n\nunion all\n\n")
      end
    end

    context "with trailing ORDER BY and LIMIT" do
      let(:output) { described_class.parse("select id from users union all select id from admins order by id limit 10").render }

      it "appends trailing clauses after a blank line" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union all

          select  id
          from    Admins a

          order by id
          limit 10
        SQL
      end
    end

    context "with complex segments containing JOINs and WHERE" do
      let(:sql) { "select users.id, orders.total from users inner join orders on orders.user_id = users.id where users.active = true union all select admins.id, requests.total from admins inner join requests on requests.admin_id = admins.id where admins.active = true" }
      let(:output) { described_class.parse(sql).render }

      it "formats each segment with its own aliases" do
        expect(output).to include("from    Users u")
        expect(output).to include("inner join Orders o on o.user_id = u.id")
        expect(output).to include("from    Admins a")
        expect(output).to include("inner join Requests r on r.admin_id = a.id")
      end
    end

    context "with three segments" do
      let(:output) { described_class.parse("select id from users union all select id from admins intersect select id from managers").render }

      it "places each operator between its respective segments" do
        expect(output).to match_formatted_text(<<~SQL)
          select  id
          from    Users u

          union all

          select  id
          from    Admins a

          intersect

          select  id
          from    Managers m
        SQL
      end
    end
  end
end
