# frozen_string_literal: true

RSpec.describe SqlBeautifier::CommentRestorer do
  describe ".call" do
    let(:output) { described_class.call(formatted_sql, comment_map) }

    ############################################################################
    ## Block comments
    ############################################################################

    context "with a :blocks sentinel" do
      let(:formatted_sql) { "select  /*__sqlb_0__*/ id\nfrom    Users u\n" }
      let(:comment_map) { { 0 => { type: :blocks, text: "/* columns */" } } }

      it "replaces the sentinel with the original block comment" do
        expect(output).to eq("select  /* columns */ id\nfrom    Users u\n")
      end
    end

    context "with multiple :blocks sentinels" do
      let(:formatted_sql) { "select  /*__sqlb_0__*/ id\nfrom    /*__sqlb_1__*/ Users u\n" }
      let(:comment_map) do
        {
          0 => { type: :blocks, text: "/* pk */" },
          1 => { type: :blocks, text: "/* source */" },
        }
      end

      it "replaces all sentinels" do
        expect(output).to eq("select  /* pk */ id\nfrom    /* source */ Users u\n")
      end
    end

    ############################################################################
    ## Separate-line comments
    ############################################################################

    context "with a :separate_line sentinel at the start" do
      let(:formatted_sql) { "/*__sqlb_0__*/\nselect  id\nfrom    Users u\n" }
      let(:comment_map) { { 0 => { type: :separate_line, text: "-- banner" } } }

      it "replaces the sentinel with the original comment on its own line" do
        expect(output).to eq("-- banner\nselect  id\nfrom    Users u\n")
      end
    end

    context "with a multi-line :separate_line sentinel" do
      let(:formatted_sql) { "/*__sqlb_0__*/\nselect  1\n" }
      let(:comment_map) { { 0 => { type: :separate_line, text: "-- line one\n-- line two" } } }

      it "restores all comment lines" do
        expect(output).to eq("-- line one\n-- line two\nselect  1\n")
      end
    end

    context "with a banner-style :separate_line sentinel" do
      let(:formatted_sql) { "/*__sqlb_0__*/\nselect  1\n" }
      let(:comment_map) do
        {
          0 => {
            type: :separate_line,
            text: "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------",
          },
        }
      end

      it "restores the full banner" do
        expected = "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nselect  1\n"
        expect(output).to eq(expected)
      end
    end

    context "with a :separate_line sentinel between clauses" do
      let(:formatted_sql) { "select  id\n/*__sqlb_0__*/\nfrom    Users u\n" }
      let(:comment_map) { { 0 => { type: :separate_line, text: "-- divider" } } }

      it "replaces the sentinel with the comment" do
        expect(output).to eq("select  id\n-- divider\nfrom    Users u\n")
      end
    end

    ############################################################################
    ## Inline comments
    ############################################################################

    context "with an :inline sentinel at end of a line" do
      let(:formatted_sql) { "select  id /*__sqlb_0__*/\nfrom    Users u\n" }
      let(:comment_map) { { 0 => { type: :inline, text: "-- primary key" } } }

      it "replaces the sentinel with the inline comment" do
        expect(output).to eq("select  id -- primary key\nfrom    Users u\n")
      end
    end

    context "with an :inline sentinel followed by trailing content on the same line" do
      let(:formatted_sql) { "select  id /*__sqlb_0__*/,\n        name\nfrom    Users u\n" }
      let(:comment_map) { { 0 => { type: :inline, text: "-- primary key" } } }

      it "moves trailing content before the comment" do
        expect(output).to eq("select  id, -- primary key\n        name\nfrom    Users u\n")
      end
    end

    context "with an :inline sentinel with no trailing content" do
      let(:formatted_sql) { "select  id /*__sqlb_0__*/\n" }
      let(:comment_map) { { 0 => { type: :inline, text: "-- pk" } } }

      it "replaces with the comment" do
        expect(output).to eq("select  id -- pk\n")
      end
    end

    ############################################################################
    ## Empty comment map
    ############################################################################

    context "with an empty comment map" do
      let(:formatted_sql) { "select  id\nfrom    Users u\n" }
      let(:comment_map) { {} }

      it "returns the sql unchanged" do
        expect(output).to eq(formatted_sql)
      end
    end

    ############################################################################
    ## Mixed types
    ############################################################################

    context "with multiple sentinel types" do
      let(:formatted_sql) { "/*__sqlb_0__*/\nselect  /*__sqlb_1__*/ id /*__sqlb_2__*/\nfrom    Users u\n" }
      let(:comment_map) do
        {
          0 => { type: :separate_line, text: "-- header" },
          1 => { type: :blocks, text: "/* cols */" },
          2 => { type: :inline, text: "-- pk" },
        }
      end

      it "restores all comment types" do
        expect(output).to eq("-- header\nselect  /* cols */ id -- pk\nfrom    Users u\n")
      end
    end
  end
end
