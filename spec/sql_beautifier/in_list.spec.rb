# frozen_string_literal: true

RSpec.describe SqlBeautifier::InList, ".format_in_text" do
  let(:output) { described_class.format_in_text(value, base_indent: base_indent) }
  let(:base_indent) { 0 }

  context "with no IN keyword" do
    let(:value) { "active = true" }

    it "returns the text unchanged" do
      expect(output).to eq("active = true")
    end
  end

  context "with an IN list containing multiple items" do
    let(:value) { "status in ('active', 'pending', 'banned')" }

    it "formats the list across multiple lines" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        status in (
        ····'active',
        ····'pending',
        ····'banned'
        )
      SQL
    end
  end

  context "with an IN list containing a single item" do
    let(:value) { "status in ('active')" }

    it "keeps the list inline" do
      expect(output).to eq("status in ('active')")
    end
  end

  context "with NOT IN and multiple items" do
    let(:value) { "status not in ('deleted', 'banned')" }

    it "formats the list across multiple lines" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        status not in (
        ····'deleted',
        ····'banned'
        )
      SQL
    end
  end

  context "with an IN subquery" do
    let(:value) { "id in (select user_id from orders)" }

    it "leaves the subquery alone" do
      expect(output).to eq("id in (select user_id from orders)")
    end
  end

  context "with numeric items" do
    let(:value) { "x in (1, 2, 3)" }

    it "formats the list across multiple lines" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        x in (
        ····1,
        ····2,
        ····3
        )
      SQL
    end
  end

  context "with items containing escaped single quotes" do
    let(:value) { "name in ('it''s', 'he''s')" }

    it "formats the list across multiple lines" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        name in (
        ····'it''s',
        ····'he''s'
        )
      SQL
    end
  end

  context "with items containing function calls" do
    let(:value) { "x in (lower('A'), lower('B'))" }

    it "formats each function call as a separate item" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        x in (
        ····lower('A'),
        ····lower('B')
        )
      SQL
    end
  end

  context "with multiple IN lists in the same text" do
    let(:value) { "a in (1, 2) and b in (3, 4)" }

    it "formats both lists across multiple lines" do
      expect(output).to match_formatted_text(<<~SQL.chomp)
        a in (
        ····1,
        ····2
        ) and b in (
        ····3,
        ····4
        )
      SQL
    end
  end

  context "with the in keyword inside a quoted string" do
    let(:value) { "name = 'in (1, 2)'" }

    it "does not format quoted content" do
      expect(output).to eq("name = 'in (1, 2)'")
    end
  end

  context "with the in keyword as part of another word" do
    let(:value) { "login(1, 2)" }

    it "does not treat it as an IN list" do
      expect(output).to eq("login(1, 2)")
    end
  end

  context "with NOT IN and a subquery" do
    let(:value) { "id not in (select user_id from orders)" }

    it "leaves the subquery alone" do
      expect(output).to eq("id not in (select user_id from orders)")
    end
  end
end
