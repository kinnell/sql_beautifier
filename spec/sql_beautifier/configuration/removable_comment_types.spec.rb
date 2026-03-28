# frozen_string_literal: true

RSpec.describe "removable_comment_types configuration" do
  let(:output) { SqlBeautifier.call(value) }

  before do
    SqlBeautifier.configure do |config|
      config.removable_comment_types = config_value
    end
  end

  ############################################################################
  ## removable_comment_types: :none (default)
  ############################################################################

  context "when removable_comment_types is :none (default)" do
    let(:config_value) { :none }

    context "with a separate-line comment before a query" do
      let(:value) { "-- header\nSELECT id FROM users" }

      it "preserves the comment" do
        expect(output).to include("-- header")
      end
    end

    context "with a banner comment before a query" do
      let(:value) { "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nSELECT id FROM users" }

      it "preserves the full banner" do
        expect(output).to start_with("--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\n")
      end
    end

    context "with an inline comment" do
      let(:value) { "SELECT id -- primary key\nFROM users" }

      it "preserves the inline comment" do
        expect(output).to include("-- primary key")
      end
    end

    context "with a block comment" do
      let(:value) { "SELECT /* main columns */ id FROM users" }

      it "preserves the block comment" do
        expect(output).to include("/* main columns */")
      end
    end

    context "with all comment types in a single query" do
      let(:value) { "-- header\nSELECT /* cols */ id -- pk\nFROM users" }

      it "preserves the separate-line comment" do
        expect(output).to include("-- header")
      end

      it "preserves the block comment" do
        expect(output).to include("/* cols */")
      end

      it "preserves the inline comment" do
        expect(output).to include("-- pk")
      end
    end

    context "with a separate-line comment between two statements" do
      let(:value) { "SELECT id FROM users;\n-- next query\nSELECT name FROM departments" }

      it "preserves the comment between statements" do
        expect(output).to include("-- next query")
      end

      it "formats both statements" do
        expect(output).to include("from    Users u")
        expect(output).to include("from    Departments d")
      end
    end

    context "with a comment-only input" do
      let(:value) { "-- just a comment" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  ############################################################################
  ## removable_comment_types: :all
  ############################################################################

  context "when removable_comment_types is :all" do
    let(:config_value) { :all }

    context "with a separate-line comment before a query" do
      let(:value) { "-- header\nSELECT id FROM users" }

      it "strips the comment" do
        expect(output).not_to include("-- header")
      end

      it "formats the query" do
        expect(output).to include("select  id")
      end
    end

    context "with a banner comment before a query" do
      let(:value) { "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nSELECT id FROM users" }

      it "strips the entire banner" do
        expect(output).not_to include("Base Query")
        expect(output).not_to include("----")
      end
    end

    context "with an inline comment" do
      let(:value) { "SELECT id -- primary key\nFROM users" }

      it "strips the inline comment" do
        expect(output).not_to include("-- primary key")
      end
    end

    context "with a block comment" do
      let(:value) { "SELECT /* main columns */ id FROM users" }

      it "strips the block comment" do
        expect(output).not_to include("/* main columns */")
      end
    end

    context "with all comment types in a single query" do
      let(:value) { "-- header\nSELECT /* cols */ id -- pk\nFROM users" }

      it "strips all comments" do
        expect(output).not_to include("--")
        expect(output).not_to include("/*")
      end

      it "formats the query" do
        expect(output).to include("select  id")
        expect(output).to include("from    Users u")
      end
    end

    context "with comments inside string literals" do
      let(:value) { "SELECT * FROM users WHERE name = 'test--value' AND bio = 'has /* stars */'" }

      it "preserves comment-like characters inside strings" do
        expect(output).to include("'test--value'")
        expect(output).to include("'has /* stars */'")
      end
    end

    context "with two statements and comments" do
      let(:value) { "-- first\nSELECT id FROM users;\n-- second\nSELECT name FROM departments" }

      it "strips all comments" do
        expect(output).not_to include("--")
      end

      it "formats both statements" do
        expect(output).to include("from    Users u")
        expect(output).to include("from    Departments d")
      end
    end
  end

  ############################################################################
  ## removable_comment_types: :inline
  ############################################################################

  context "when removable_comment_types is :inline" do
    let(:config_value) { :inline }

    context "with an inline comment and a separate-line comment" do
      let(:value) { "-- header\nSELECT id -- pk\nFROM users" }

      it "strips the inline comment" do
        expect(output).not_to include("-- pk")
      end

      it "preserves the separate-line comment" do
        expect(output).to include("-- header")
      end
    end

    context "with an inline comment and a block comment" do
      let(:value) { "SELECT /* cols */ id -- pk\nFROM users" }

      it "strips the inline comment" do
        expect(output).not_to include("-- pk")
      end

      it "preserves the block comment" do
        expect(output).to include("/* cols */")
      end
    end
  end

  ############################################################################
  ## removable_comment_types: :separate_line
  ############################################################################

  context "when removable_comment_types is :separate_line" do
    let(:config_value) { :separate_line }

    context "with a separate-line comment and an inline comment" do
      let(:value) { "-- header\nSELECT id -- pk\nFROM users" }

      it "strips the separate-line comment" do
        expect(output).not_to include("-- header")
      end

      it "preserves the inline comment" do
        expect(output).to include("-- pk")
      end
    end

    context "with a banner comment before a query" do
      let(:value) { "--------------------------------------------------------------------------------\n-- Base Query (34ms)\n--------------------------------------------------------------------------------\nSELECT id FROM users" }

      it "strips the entire banner" do
        expect(output).not_to include("Base Query")
        expect(output).not_to include("----")
      end

      it "formats the query" do
        expect(output).to include("select  id")
      end
    end

    context "with a separate-line comment and a block comment" do
      let(:value) { "-- header\nSELECT /* cols */ id FROM users" }

      it "strips the separate-line comment" do
        expect(output).not_to include("-- header")
      end

      it "preserves the block comment" do
        expect(output).to include("/* cols */")
      end
    end
  end

  ############################################################################
  ## removable_comment_types: :blocks
  ############################################################################

  context "when removable_comment_types is :blocks" do
    let(:config_value) { :blocks }

    context "with a block comment and an inline comment" do
      let(:value) { "SELECT /* cols */ id -- pk\nFROM users" }

      it "strips the block comment" do
        expect(output).not_to include("/* cols */")
      end

      it "preserves the inline comment" do
        expect(output).to include("-- pk")
      end
    end

    context "with a block comment and a separate-line comment" do
      let(:value) { "-- header\nSELECT /* cols */ id FROM users" }

      it "strips the block comment" do
        expect(output).not_to include("/* cols */")
      end

      it "preserves the separate-line comment" do
        expect(output).to include("-- header")
      end
    end

    context "with a multi-line block comment" do
      let(:value) { "SELECT id\n/* multi\nline\ncomment */\nFROM users" }

      it "strips the multi-line block comment" do
        expect(output).not_to include("multi")
        expect(output).not_to include("/*")
      end
    end
  end

  ############################################################################
  ## removable_comment_types: arrays (multiple types)
  ############################################################################

  context "when removable_comment_types is [:inline, :blocks]" do
    let(:config_value) { %i[inline blocks] }

    context "with all comment types" do
      let(:value) { "-- header\nSELECT /* cols */ id -- pk\nFROM users" }

      it "strips inline comments" do
        expect(output).not_to include("-- pk")
      end

      it "strips block comments" do
        expect(output).not_to include("/* cols */")
      end

      it "preserves separate-line comments" do
        expect(output).to include("-- header")
      end
    end
  end

  context "when removable_comment_types is [:inline, :separate_line]" do
    let(:config_value) { %i[inline separate_line] }

    context "with all comment types" do
      let(:value) { "-- header\nSELECT /* cols */ id -- pk\nFROM users" }

      it "strips inline comments" do
        expect(output).not_to include("-- pk")
      end

      it "strips separate-line comments" do
        expect(output).not_to include("-- header")
      end

      it "preserves block comments" do
        expect(output).to include("/* cols */")
      end
    end
  end

  context "when removable_comment_types is [:blocks, :separate_line]" do
    let(:config_value) { %i[blocks separate_line] }

    context "with all comment types" do
      let(:value) { "-- header\nSELECT /* cols */ id -- pk\nFROM users" }

      it "strips block comments" do
        expect(output).not_to include("/* cols */")
      end

      it "strips separate-line comments" do
        expect(output).not_to include("-- header")
      end

      it "preserves inline comments" do
        expect(output).to include("-- pk")
      end
    end
  end

  ############################################################################
  ## Per-call override
  ############################################################################

  context "with a per-call override" do
    let(:config_value) { :none }
    let(:value) { "-- header\nSELECT id -- pk\nFROM users" }
    let(:output) { SqlBeautifier.call(value, removable_comment_types: :all) }

    it "uses the per-call value instead of the global config" do
      expect(output).not_to include("--")
    end
  end

  context "when a global config is :all and per-call overrides to :none" do
    let(:config_value) { :all }
    let(:value) { "-- header\nSELECT id FROM users" }
    let(:output) { SqlBeautifier.call(value, removable_comment_types: :none) }

    it "preserves all comments per the override" do
      expect(output).to include("-- header")
    end
  end
end
