# frozen_string_literal: true

RSpec.describe "inline_group_threshold configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.inline_group_threshold = config_value
    end
  end

  ############################################################################
  ## inline_group_threshold: 0 (default — always expand)
  ############################################################################

  context "when inline_group_threshold is 0 (default)" do
    let(:config_value) { 0 }

    context "with a short parenthesized group in WHERE" do
      let(:value) { "SELECT id FROM users WHERE active = true AND (role = 'admin' OR role = 'mod')" }

      it "always expands the group to multiple lines" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (
                      role = 'admin'
                      or role = 'mod'
                  );
        SQL
      end
    end

    context "with multiple parenthesized groups" do
      let(:value) { "SELECT id FROM users WHERE (a = 1 OR b = 2) AND (c = 3 OR d = 4)" }

      it "expands every group to multiple lines" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   (
                      a = 1
                      or b = 2
                  )
                  and (
                      c = 3
                      or d = 4
                  );
        SQL
      end
    end

    context "with a single parenthesized group as the only condition" do
      let(:value) { "SELECT id FROM users WHERE (active = true AND verified = true)" }

      it "keeps it as a single top-level condition" do
        expect(output).to eq(<<~SQL)
          select  id
          from    Users u
          where   (active = true and verified = true);
        SQL
      end
    end
  end

  ############################################################################
  ## inline_group_threshold: 100 (generous — keep short groups inline)
  ############################################################################

  context "when inline_group_threshold is 100" do
    let(:config_value) { 100 }

    context "with a short parenthesized group in WHERE" do
      let(:value) { "SELECT id FROM users WHERE active = true AND (role = 'admin' OR role = 'mod')" }

      it "keeps the short group inline" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'mod');
        SQL
      end
    end

    context "with a long parenthesized group that exceeds the threshold" do
      let(:value) { "SELECT id FROM users WHERE active = true AND (very_long_column_name_alpha = 'some_very_long_value_here' OR very_long_column_name_beta = 'another_very_long_value_there')" }

      it "expands the long group to multiple lines" do
        expect(output).to eq(<<~SQL)
          select  id

          from    Users u

          where   active = true
                  and (
                      very_long_column_name_alpha = 'some_very_long_value_here'
                      or very_long_column_name_beta = 'another_very_long_value_there'
                  );
        SQL
      end
    end
  end

  ############################################################################
  ## inline_group_threshold: exact boundary
  ############################################################################

  context "when inline_group_threshold equals the inline group length" do
    let(:value) { "SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')" }

    context "when threshold is 1 below the inline length" do
      let(:config_value) { 37 }

      it "expands the group" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (
                      role = 'admin'
                      or role = 'moderator'
                  );
        SQL
      end
    end

    context "when threshold exactly matches the inline length" do
      let(:config_value) { 38 }

      it "keeps the group inline" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator');
        SQL
      end
    end

    context "when threshold is 1 above the inline length" do
      let(:config_value) { 39 }

      it "keeps the group inline" do
        expect(output).to eq(<<~SQL)
          select  *

          from    Users u

          where   active = true
                  and (role = 'admin' or role = 'moderator');
        SQL
      end
    end
  end
end
