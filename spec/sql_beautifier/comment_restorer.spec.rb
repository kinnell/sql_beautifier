# frozen_string_literal: true

RSpec.describe SqlBeautifier::CommentParser, ".restore" do
  let(:output) { described_class.restore(formatted_sql, comment_map) }

  ############################################################################
  ## Block comments
  ############################################################################

  context "with a :blocks sentinel" do
    let(:formatted_sql) do
      <<~SQL
        select  /*__sqlb_0__*/ id
        from    Users u
      SQL
    end

    let(:comment_map) { { 0 => { type: :blocks, text: "/* columns */" } } }

    it "replaces the sentinel with the original block comment" do
      expect(output).to eq(<<~SQL)
        select  /* columns */ id
        from    Users u
      SQL
    end
  end

  context "with multiple :blocks sentinels" do
    let(:formatted_sql) do
      <<~SQL
        select  /*__sqlb_0__*/ id
        from    /*__sqlb_1__*/ Users u
      SQL
    end

    let(:comment_map) do
      {
        0 => { type: :blocks, text: "/* pk */" },
        1 => { type: :blocks, text: "/* source */" },
      }
    end

    it "replaces all sentinels" do
      expect(output).to eq(<<~SQL)
        select  /* pk */ id
        from    /* source */ Users u
      SQL
    end
  end

  ############################################################################
  ## Separate-line comments
  ############################################################################

  context "with a :line sentinel at the start" do
    let(:formatted_sql) do
      <<~SQL
        /*__sqlb_0__*/
        select  id
        from    Users u
      SQL
    end

    let(:comment_map) { { 0 => { type: :line, text: "-- banner" } } }

    it "replaces the sentinel with the original comment on its own line" do
      expect(output).to eq(<<~SQL)
        -- banner
        select  id
        from    Users u
      SQL
    end
  end

  context "with a multi-line :line sentinel" do
    let(:formatted_sql) do
      <<~SQL
        /*__sqlb_0__*/
        select  1
      SQL
    end

    let(:comment_map) { { 0 => { type: :line, text: "-- line one\n-- line two" } } }

    it "restores all comment lines" do
      expect(output).to eq(<<~SQL)
        -- line one
        -- line two
        select  1
      SQL
    end
  end

  context "with a banner-style :line sentinel" do
    let(:formatted_sql) do
      <<~SQL
        /*__sqlb_0__*/
        select  1
      SQL
    end

    let(:comment_map) do
      {
        0 => {
          type: :line,
          text: "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------",
        },
      }
    end

    it "restores the full banner" do
      expect(output).to eq(<<~SQL)
        --------------------------------------------------------------------------------
        -- Base Query (34ms)
        --------------------------------------------------------------------------------
        select  1
      SQL
    end
  end

  context "with a :line sentinel between clauses" do
    let(:formatted_sql) do
      <<~SQL
        select  id
        /*__sqlb_0__*/
        from    Users u
      SQL
    end

    let(:comment_map) { { 0 => { type: :line, text: "-- divider" } } }

    it "replaces the sentinel with the comment" do
      expect(output).to eq(<<~SQL)
        select  id
        -- divider
        from    Users u
      SQL
    end
  end

  ############################################################################
  ## Inline comments
  ############################################################################

  context "with an :inline sentinel at end of a line" do
    let(:formatted_sql) do
      <<~SQL
        select  id /*__sqlb_0__*/
        from    Users u
      SQL
    end

    let(:comment_map) { { 0 => { type: :inline, text: "-- primary key" } } }

    it "replaces the sentinel with the inline comment" do
      expect(output).to eq(<<~SQL)
        select  id -- primary key
        from    Users u
      SQL
    end
  end

  context "with an :inline sentinel followed by trailing content on the same line" do
    let(:formatted_sql) do
      <<~SQL
        select  id /*__sqlb_0__*/,
                name
        from    Users u
      SQL
    end

    let(:comment_map) { { 0 => { type: :inline, text: "-- primary key" } } }

    it "moves trailing content before the comment" do
      expect(output).to eq(<<~SQL)
        select  id, -- primary key
                name
        from    Users u
      SQL
    end
  end

  context "with an :inline sentinel with no trailing content" do
    let(:formatted_sql) do
      <<~SQL
        select  id /*__sqlb_0__*/
      SQL
    end

    let(:comment_map) { { 0 => { type: :inline, text: "-- pk" } } }

    it "replaces with the comment" do
      expect(output).to eq(<<~SQL)
        select  id -- pk
      SQL
    end
  end

  ############################################################################
  ## Empty comment map
  ############################################################################

  context "with an empty comment map" do
    let(:formatted_sql) do
      <<~SQL
        select  id
        from    Users u
      SQL
    end

    let(:comment_map) { {} }

    it "returns the sql unchanged" do
      expect(output).to eq(formatted_sql)
    end
  end

  ############################################################################
  ## Mixed types
  ############################################################################

  context "with multiple sentinel types" do
    let(:formatted_sql) do
      <<~SQL
        /*__sqlb_0__*/
        select  /*__sqlb_1__*/ id /*__sqlb_2__*/
        from    Users u
      SQL
    end

    let(:comment_map) do
      {
        0 => { type: :line, text: "-- header" },
        1 => { type: :blocks, text: "/* cols */" },
        2 => { type: :inline, text: "-- pk" },
      }
    end

    it "restores all comment types" do
      expect(output).to eq(<<~SQL)
        -- header
        select  /* cols */ id -- pk
        from    Users u
      SQL
    end
  end
end
