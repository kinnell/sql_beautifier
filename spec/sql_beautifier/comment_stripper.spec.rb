# frozen_string_literal: true

RSpec.describe SqlBeautifier::CommentStripper do
  describe ".call" do
    let(:result) { described_class.call(sql, removable_types) }
    let(:stripped_sql) { result.stripped_sql }
    let(:comment_map) { result.comment_map }

    ############################################################################
    ## Removing all comment types
    ############################################################################

    context "when removable_types is :all" do
      let(:removable_types) { :all }

      context "with a -- separate-line comment" do
        let(:sql) { "-- banner\nSELECT id FROM users" }

        it "strips the comment" do
          expect(stripped_sql).to eq("\nSELECT id FROM users")
        end

        it "returns an empty comment map" do
          expect(comment_map).to be_empty
        end
      end

      context "with a -- inline comment" do
        let(:sql) { "SELECT id -- primary key\nFROM users" }

        it "strips the comment" do
          expect(stripped_sql).to eq("SELECT id \nFROM users")
        end

        it "returns an empty comment map" do
          expect(comment_map).to be_empty
        end
      end

      context "with a /* */ block comment" do
        let(:sql) { "SELECT /* columns */ id FROM users" }

        it "strips the comment and inserts a space for token separation" do
          expect(stripped_sql).to eq("SELECT  id FROM users")
        end

        it "returns an empty comment map" do
          expect(comment_map).to be_empty
        end
      end

      context "with a block comment between tokens with no space" do
        let(:sql) { "SELECT/*columns*/id FROM users" }

        it "inserts a space for token separation" do
          expect(stripped_sql).to eq("SELECT id FROM users")
        end
      end
    end

    ############################################################################
    ## Preserving all comment types
    ############################################################################

    context "when removable_types is :none" do
      let(:removable_types) { :none }

      context "with a -- separate-line comment" do
        let(:sql) { "-- banner\nSELECT id FROM users" }

        it "replaces the comment with a sentinel" do
          expect(stripped_sql).to match(%r{\A/\*__sqlb_\d+__\*/\nSELECT id FROM users\z})
        end

        it "records the comment as :separate_line" do
          expect(comment_map.values.first[:type]).to eq(:separate_line)
        end

        it "records the original comment text" do
          expect(comment_map.values.first[:text]).to eq("-- banner")
        end
      end

      context "with a -- inline comment" do
        let(:sql) { "SELECT id -- primary key\nFROM users" }

        it "replaces the comment with a sentinel" do
          expect(stripped_sql).to match(%r{\ASELECT id /\*__sqlb_\d+__\*/\nFROM users\z})
        end

        it "records the comment as :inline" do
          expect(comment_map.values.first[:type]).to eq(:inline)
        end

        it "records the original comment text" do
          expect(comment_map.values.first[:text]).to eq("-- primary key")
        end
      end

      context "with a /* */ block comment" do
        let(:sql) { "SELECT /* columns */ id FROM users" }

        it "replaces the comment with a sentinel" do
          expect(stripped_sql).to match(%r{\ASELECT /\*__sqlb_\d+__\*/ id FROM users\z})
        end

        it "records the comment as :blocks" do
          expect(comment_map.values.first[:type]).to eq(:blocks)
        end

        it "records the original comment text" do
          expect(comment_map.values.first[:text]).to eq("/* columns */")
        end
      end

      context "with a block comment between tokens with no whitespace" do
        let(:sql) { "SELECT/*comment*/id FROM users" }

        it "inserts spaces around the sentinel for token separation" do
          expect(stripped_sql).to match(%r{\ASELECT /\*__sqlb_\d+__\*/ id FROM users\z})
        end
      end

      context "with consecutive separate-line comments" do
        let(:sql) { "-- line one\n-- line two\nSELECT 1" }

        it "groups them into a single sentinel" do
          expect(stripped_sql).to match(%r{\A/\*__sqlb_\d+__\*/\nSELECT 1\z})
        end

        it "records the grouped text" do
          expect(comment_map.values.first[:text]).to eq("-- line one\n-- line two")
        end
      end

      context "with a banner-style comment block" do
        let(:sql) do
          <<~SQL
            --------------------------------------------------------------------------------
            -- Base Query (34ms)
            --------------------------------------------------------------------------------
            SELECT 1
          SQL
        end

        it "groups the banner into a single sentinel" do
          expect(comment_map.length).to eq(1)
        end

        it "preserves the full banner text" do
          expect(comment_map.values.first[:text]).to eq(<<~TEXT.chomp)
            --------------------------------------------------------------------------------
            -- Base Query (34ms)
            --------------------------------------------------------------------------------
          TEXT
        end
      end
    end

    ############################################################################
    ## Selective removal
    ############################################################################

    context "when removable_types is [:inline]" do
      let(:removable_types) { %i[inline] }
      let(:sql) { "-- banner\nSELECT id -- pk\nFROM /* src */ users" }

      it "strips the inline comment" do
        expect(stripped_sql).not_to include("-- pk")
      end

      it "preserves the separate-line comment as a sentinel" do
        expect(comment_map.values).to include(a_hash_including(type: :separate_line))
      end

      it "preserves the block comment as a sentinel" do
        expect(comment_map.values).to include(a_hash_including(type: :blocks))
      end
    end

    context "when removable_types is [:separate_line]" do
      let(:removable_types) { %i[separate_line] }
      let(:sql) { "-- banner\nSELECT id -- pk\nFROM users" }

      it "strips the separate-line comment" do
        expect(stripped_sql).not_to include("banner")
      end

      it "preserves the inline comment as a sentinel" do
        expect(comment_map.values).to include(a_hash_including(type: :inline, text: "-- pk"))
      end
    end

    context "when removable_types is [:blocks]" do
      let(:removable_types) { %i[blocks] }
      let(:sql) { "SELECT id -- pk\nFROM /* src */ users" }

      it "strips the block comment" do
        expect(stripped_sql).not_to include("src")
      end

      it "preserves the inline comment as a sentinel" do
        expect(comment_map.values).to include(a_hash_including(type: :inline, text: "-- pk"))
      end
    end

    ############################################################################
    ## String and identifier awareness
    ############################################################################

    context "with -- inside a single-quoted string" do
      let(:removable_types) { :all }
      let(:sql) { "SELECT * FROM users WHERE name = 'test--value'" }

      it "preserves the string content" do
        expect(stripped_sql).to eq("SELECT * FROM users WHERE name = 'test--value'")
      end

      it "does not record a comment" do
        expect(comment_map).to be_empty
      end
    end

    context "with /* */ inside a single-quoted string" do
      let(:removable_types) { :all }
      let(:sql) { "SELECT * FROM users WHERE name = 'test/**/value'" }

      it "preserves the string content" do
        expect(stripped_sql).to eq("SELECT * FROM users WHERE name = 'test/**/value'")
      end
    end

    context "with -- inside a double-quoted identifier" do
      let(:removable_types) { :all }
      let(:sql) { 'SELECT "User--Name" FROM users' }

      it "preserves the identifier content" do
        expect(stripped_sql).to eq('SELECT "User--Name" FROM users')
      end
    end

    context "with /* */ inside a double-quoted identifier" do
      let(:removable_types) { :all }
      let(:sql) { 'SELECT "Cost/*Center*/Code" FROM users' }

      it "preserves the identifier content" do
        expect(stripped_sql).to eq('SELECT "Cost/*Center*/Code" FROM users')
      end
    end

    context "with an escaped single quote in a string literal" do
      let(:removable_types) { :all }
      let(:sql) { "SELECT * FROM users WHERE name = 'O''Brien' -- name" }

      it "handles the escaped quote and strips the comment" do
        expect(stripped_sql).to eq("SELECT * FROM users WHERE name = 'O''Brien' ")
      end
    end

    ############################################################################
    ## Edge cases
    ############################################################################

    context "with no comments" do
      let(:removable_types) { :none }
      let(:sql) { "SELECT id FROM users" }

      it "returns the sql unchanged" do
        expect(stripped_sql).to eq("SELECT id FROM users")
      end

      it "returns an empty comment map" do
        expect(comment_map).to be_empty
      end
    end

    context "with a comment-only input" do
      let(:removable_types) { :none }
      let(:sql) { "-- just a comment" }

      it "replaces with a sentinel" do
        expect(stripped_sql).to match(%r{\A/\*__sqlb_\d+__\*/\n\z})
      end
    end

    context "with a block comment at the start with no space" do
      let(:removable_types) { :all }
      let(:sql) { "/*header*/SELECT id FROM users" }

      it "strips the comment without a leading space when output is empty" do
        expect(stripped_sql).to eq("SELECT id FROM users")
      end
    end

    context "with a multi-line block comment" do
      let(:removable_types) { :none }
      let(:sql) { "SELECT id\n/* multi\nline\ncomment */\nFROM users" }

      it "records the type as :blocks" do
        expect(comment_map.values.first[:type]).to eq(:blocks)
      end

      it "preserves the full block comment text" do
        expect(comment_map.values.first[:text]).to eq("/* multi\nline\ncomment */")
      end
    end

    context "with a separate-line comment with leading whitespace" do
      let(:removable_types) { :none }
      let(:sql) { "  -- indented comment\nSELECT 1" }

      it "classifies as :separate_line" do
        expect(comment_map.values.first[:type]).to eq(:separate_line)
      end
    end

    context "with multiple mixed comments" do
      let(:removable_types) { :none }
      let(:sql) { "/* header */ SELECT id -- inline\n-- separate\nFROM users" }

      it "records all three comment types" do
        types = comment_map.values.map { |entry| entry[:type] }
        expect(types).to contain_exactly(:blocks, :inline, :separate_line)
      end
    end

    ############################################################################
    ## Invalid removable_types
    ############################################################################

    context "when removable_types is an unrecognized symbol" do
      let(:removable_types) { :bogus }
      let(:sql) { "SELECT 1" }

      it "raises an ArgumentError" do
        expect { result }.to raise_error(ArgumentError, %r{Unsupported removable_types})
      end
    end

    context "when removable_types is nil" do
      let(:removable_types) { nil }
      let(:sql) { "SELECT 1" }

      it "raises an ArgumentError" do
        expect { result }.to raise_error(ArgumentError, %r{Unsupported removable_types})
      end
    end

    context "when removable_types is a String" do
      let(:removable_types) { "all" }
      let(:sql) { "SELECT 1" }

      it "raises an ArgumentError" do
        expect { result }.to raise_error(ArgumentError, %r{Unsupported removable_types})
      end
    end

    context "when removable_types is an Array with an invalid element" do
      let(:removable_types) { %i[inline bogus] }
      let(:sql) { "SELECT 1" }

      it "raises an ArgumentError" do
        expect { result }.to raise_error(ArgumentError, %r{bogus})
      end
    end

    context "when removable_types is an Array with all invalid elements" do
      let(:removable_types) { %i[foo bar] }
      let(:sql) { "SELECT 1" }

      it "raises an ArgumentError" do
        expect { result }.to raise_error(ArgumentError, %r{foo.*bar})
      end
    end
  end
end
