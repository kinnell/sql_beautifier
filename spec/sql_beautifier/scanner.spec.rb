# frozen_string_literal: true

RSpec.describe SqlBeautifier::Scanner do
  ############################################################################
  ## Initialization
  ############################################################################

  describe "#initialize" do
    let(:scanner) { described_class.new(source) }
    let(:source) { "select 1" }

    it "starts at position zero" do
      expect(scanner.position).to eq(0)
    end

    it "stores the source string" do
      expect(scanner.source).to eq(source)
    end

    it "starts at :parenthesis_depth zero" do
      expect(scanner.parenthesis_depth).to eq(0)
    end

    context "with a custom starting position" do
      let(:scanner) { described_class.new(source, position: 4) }

      it "starts at the specified position" do
        expect(scanner.position).to eq(4)
      end
    end
  end

  ############################################################################
  ## Position and Character Access
  ############################################################################

  describe "#finished?" do
    let(:scanner) { described_class.new(source, position: position) }
    let(:source) { "abc" }
    let(:position) { 0 }

    context "when the position is before the end" do
      it "returns false" do
        expect(scanner).not_to be_finished
      end
    end

    context "when the position is at the end" do
      let(:position) { 3 }

      it "returns true" do
        expect(scanner).to be_finished
      end
    end

    context "when the source is empty" do
      let(:source) { "" }

      it "returns true" do
        expect(scanner).to be_finished
      end
    end
  end

  describe "#current_char" do
    let(:scanner) { described_class.new("abc", position: 1) }

    it "returns the character at the current position" do
      expect(scanner.current_char).to eq("b")
    end
  end

  describe "#peek" do
    let(:scanner) { described_class.new("abcd") }

    context "with default offset" do
      it "returns the next character" do
        expect(scanner.peek).to eq("b")
      end
    end

    context "with a custom offset" do
      it "returns the character at the given offset" do
        expect(scanner.peek(2)).to eq("c")
      end
    end
  end

  ############################################################################
  ## State Queries
  ############################################################################

  describe "#top_level?" do
    let(:scanner) { described_class.new("select") }

    context "when at depth zero and not in a quoted context" do
      it "returns true" do
        expect(scanner).to be_top_level
      end
    end

    context "when inside parentheses" do
      before { scanner.increment_depth! }

      it "returns false" do
        expect(scanner).not_to be_top_level
      end
    end

    context "when inside a single-quoted string" do
      before { scanner.enter_single_quote! }

      it "returns false" do
        expect(scanner).not_to be_top_level
      end
    end

    context "when inside a double-quoted identifier" do
      before { scanner.enter_double_quote! }

      it "returns false" do
        expect(scanner).not_to be_top_level
      end
    end
  end

  describe "#in_quoted_context?" do
    let(:scanner) { described_class.new("abc") }

    context "when not in any quoted context" do
      it "returns false" do
        expect(scanner).not_to be_in_quoted_context
      end
    end

    context "when inside a single-quoted string" do
      before { scanner.enter_single_quote! }

      it "returns true" do
        expect(scanner).to be_in_quoted_context
      end
    end

    context "when inside a double-quoted identifier" do
      before { scanner.enter_double_quote! }

      it "returns true" do
        expect(scanner).to be_in_quoted_context
      end
    end
  end

  ############################################################################
  ## Advance and State Management
  ############################################################################

  describe "#advance!" do
    let(:scanner) { described_class.new("abcd") }

    context "with default count" do
      before { scanner.advance! }

      it "advances by one character" do
        expect(scanner.position).to eq(1)
      end
    end

    context "with a custom count" do
      before { scanner.advance!(3) }

      it "advances by the specified count" do
        expect(scanner.position).to eq(3)
      end
    end
  end

  describe "#increment_depth! and #decrement_depth!" do
    let(:scanner) { described_class.new("()") }

    context "after incrementing depth" do
      before { scanner.increment_depth! }

      it "increases :parenthesis_depth" do
        expect(scanner.parenthesis_depth).to eq(1)
      end
    end

    context "after incrementing and decrementing depth" do
      before do
        scanner.increment_depth!
        scanner.decrement_depth!
      end

      it "returns to zero" do
        expect(scanner.parenthesis_depth).to eq(0)
      end
    end

    context "when decrementing from zero" do
      before { scanner.decrement_depth! }

      it "does not go below zero" do
        expect(scanner.parenthesis_depth).to eq(0)
      end
    end
  end

  describe "#advance_through_single_quote!" do
    let(:scanner) { described_class.new(source) }

    context "with an escaped single quote" do
      let(:source) { "'it''s'" }

      before do
        scanner.enter_single_quote!
        scanner.advance!(2)
        scanner.advance_through_single_quote!
      end

      it "advances past both quote characters" do
        expect(scanner.position).to eq(5)
      end

      it "remains inside the string" do
        expect(scanner).to be_in_single_quote
      end
    end

    context "with a closing single quote" do
      let(:source) { "'ab'" }

      before do
        scanner.enter_single_quote!
        scanner.advance!(2)
        scanner.advance_through_single_quote!
      end

      it "exits the quoted string" do
        expect(scanner).not_to be_in_single_quote
      end
    end

    context "with a regular character" do
      let(:source) { "'abc'" }

      before do
        scanner.enter_single_quote!
        scanner.advance_through_single_quote!
      end

      it "advances by one character" do
        expect(scanner.position).to eq(2)
      end
    end
  end

  describe "#advance_through_double_quote!" do
    let(:scanner) { described_class.new(source) }

    context "with an escaped double quote" do
      let(:source) { '"a""b"' }

      before do
        scanner.enter_double_quote!
        scanner.advance!
        scanner.advance_through_double_quote!
      end

      it "advances past both quote characters" do
        expect(scanner.position).to eq(4)
      end

      it "remains inside the identifier" do
        expect(scanner).to be_in_double_quote
      end
    end

    context "with a closing double quote" do
      let(:source) { '"ab"' }

      before do
        scanner.enter_double_quote!
        scanner.advance!(2)
        scanner.advance_through_double_quote!
      end

      it "exits the quoted identifier" do
        expect(scanner).not_to be_in_double_quote
      end
    end
  end

  ############################################################################
  ## Consume Operations
  ############################################################################

  describe "#consume_single_quoted_string!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.consume_single_quoted_string! }

    context "with a simple string" do
      let(:source) { "'hello' rest" }

      before { output }

      it "returns the full quoted string" do
        expect(output).to eq("'hello'")
      end

      it "advances past the closing quote" do
        expect(scanner.position).to eq(7)
      end
    end

    context "with escaped quotes" do
      let(:source) { "'it''s' rest" }

      it "returns the full quoted string including the escape" do
        expect(output).to eq("'it''s'")
      end
    end
  end

  describe "#consume_double_quoted_identifier!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.consume_double_quoted_identifier! }

    context "with a simple identifier" do
      let(:source) { '"column" rest' }

      before { output }

      it "returns the full quoted identifier" do
        expect(output).to eq('"column"')
      end

      it "advances past the closing quote" do
        expect(scanner.position).to eq(8)
      end
    end

    context "with escaped quotes" do
      let(:source) { '"col""name" rest' }

      it "returns the full quoted identifier including the escape" do
        expect(output).to eq('"col""name"')
      end
    end
  end

  describe "#consume_sentinel!" do
    let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
    let(:scanner) { described_class.new("#{sentinel} rest") }
    let(:output) { scanner.consume_sentinel! }

    before { output }

    it "returns the sentinel text" do
      expect(output).to eq(sentinel)
    end

    it "advances past the sentinel" do
      expect(scanner.position).to eq(sentinel.length)
    end
  end

  describe "#consume_dollar_quoted_string!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.consume_dollar_quoted_string!(delimiter) }

    context "with a simple dollar-quoted string" do
      let(:source) { "$$body text$$ rest" }
      let(:delimiter) { "$$" }

      before { output }

      it "returns the full dollar-quoted string" do
        expect(output).to eq("$$body text$$")
      end

      it "advances past the closing delimiter" do
        expect(scanner.position).to eq(13)
      end
    end

    context "with a tagged dollar-quoted string" do
      let(:source) { "$tag$body$tag$ rest" }
      let(:delimiter) { "$tag$" }

      it "returns the full dollar-quoted string" do
        expect(output).to eq("$tag$body$tag$")
      end
    end
  end

  ############################################################################
  ## Skip Operations
  ############################################################################

  describe "#skip_single_quoted_string!" do
    let(:scanner) { described_class.new("'hello' rest") }

    before { scanner.skip_single_quoted_string! }

    it "advances past the closing quote" do
      expect(scanner.position).to eq(7)
    end
  end

  describe "#skip_double_quoted_identifier!" do
    let(:scanner) { described_class.new('"column" rest') }

    before { scanner.skip_double_quoted_identifier! }

    it "advances past the closing quote" do
      expect(scanner.position).to eq(8)
    end
  end

  describe "#skip_sentinel!" do
    let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
    let(:scanner) { described_class.new("#{sentinel} rest") }

    before { scanner.skip_sentinel! }

    it "advances past the sentinel" do
      expect(scanner.position).to eq(sentinel.length)
    end
  end

  describe "#skip_whitespace!" do
    let(:scanner) { described_class.new(source) }

    before { scanner.skip_whitespace! }

    context "with leading spaces" do
      let(:source) { "   abc" }

      it "advances past all whitespace" do
        expect(scanner.position).to eq(3)
      end
    end

    context "with mixed whitespace" do
      let(:source) { " \t\n abc" }

      it "advances past all whitespace characters" do
        expect(scanner.position).to eq(4)
      end
    end

    context "with no leading whitespace" do
      let(:source) { "abc" }

      it "does not change position" do
        expect(scanner.position).to eq(0)
      end
    end
  end

  describe "#skip_past_keyword!" do
    let(:scanner) { described_class.new("select  id from users") }

    before { scanner.skip_past_keyword!("select") }

    it "advances past the keyword and trailing whitespace" do
      expect(scanner.position).to eq(8)
    end

    it "positions at the next non-whitespace character" do
      expect(scanner.current_char).to eq("i")
    end
  end

  ############################################################################
  ## Detection Operations
  ############################################################################

  describe "#sentinel_at?" do
    let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
    let(:scanner) { described_class.new(source) }

    context "when a sentinel starts at the current position" do
      let(:source) { sentinel }

      it "returns true" do
        expect(scanner.sentinel_at?).to be true
      end
    end

    context "when no sentinel starts at the current position" do
      let(:source) { "select 1" }

      it "returns false" do
        expect(scanner.sentinel_at?).to be false
      end
    end

    context "with a custom position argument" do
      let(:source) { "abc #{sentinel}" }

      it "checks the specified position" do
        expect(scanner.sentinel_at?(4)).to be true
      end
    end
  end

  describe "#inside_sentinel?" do
    let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
    let(:scanner) { described_class.new("x #{sentinel} y") }

    context "when the position is inside a sentinel" do
      it "returns true" do
        expect(scanner.inside_sentinel?(5)).to be true
      end
    end

    context "when the position is outside a sentinel" do
      it "returns false" do
        expect(scanner.inside_sentinel?(0)).to be false
      end
    end
  end

  describe "#keyword_at?" do
    let(:scanner) { described_class.new(source) }
    let(:source) { "select id from users" }

    context "when the keyword matches at the current position" do
      it "returns true" do
        expect(scanner.keyword_at?("select")).to be true
      end
    end

    context "when the keyword does not match at the current position" do
      it "returns false" do
        expect(scanner.keyword_at?("from")).to be false
      end
    end

    context "with a custom position argument" do
      it "checks the specified position" do
        expect(scanner.keyword_at?("from", 10)).to be true
      end
    end

    context "when the match is a substring of another word" do
      let(:source) { "selective" }

      it "returns false" do
        expect(scanner.keyword_at?("select")).to be false
      end
    end

    context "with case-insensitive matching" do
      let(:source) { "SELECT id" }

      it "matches regardless of case" do
        expect(scanner.keyword_at?("select")).to be true
      end
    end
  end

  describe "#word_boundary?" do
    let(:scanner) { described_class.new("") }
    let(:output) { scanner.word_boundary?(character) }

    context "with nil" do
      let(:character) { nil }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "with a space" do
      let(:character) { " " }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "with a comma" do
      let(:character) { "," }

      it "returns true" do
        expect(output).to be true
      end
    end

    context "with a letter" do
      let(:character) { "a" }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "with a digit" do
      let(:character) { "5" }

      it "returns false" do
        expect(output).to be false
      end
    end

    context "with an underscore" do
      let(:character) { "_" }

      it "returns false" do
        expect(output).to be false
      end
    end
  end

  describe "#dollar_quote_delimiter_at" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.dollar_quote_delimiter_at }

    context "with a $$ delimiter" do
      let(:source) { "$$body$$" }

      it "returns the delimiter" do
        expect(output).to eq("$$")
      end
    end

    context "with a tagged delimiter" do
      let(:source) { "$tag$body$tag$" }

      it "returns the full tagged delimiter" do
        expect(output).to eq("$tag$")
      end
    end

    context "with no dollar quote" do
      let(:source) { "select 1" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  describe "#detect_conjunction_at" do
    let(:scanner) { described_class.new(source, position: position) }
    let(:output) { scanner.detect_conjunction_at }

    context "when AND is at the current position" do
      let(:source) { "a = 1 and b = 2" }
      let(:position) { 6 }

      it "returns the matched conjunction" do
        expect(output).to eq("and")
      end
    end

    context "when OR is at the current position" do
      let(:source) { "a = 1 or b = 2" }
      let(:position) { 6 }

      it "returns the matched conjunction" do
        expect(output).to eq("or")
      end
    end

    context "when no conjunction is at the current position" do
      let(:source) { "a = 1" }
      let(:position) { 0 }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  ############################################################################
  ## Character Inspection
  ############################################################################

  describe "#character_before" do
    let(:scanner) { described_class.new("abc") }
    let(:output) { scanner.character_before(position) }

    context "at the start of the string" do
      let(:position) { 0 }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a valid preceding character" do
      let(:position) { 2 }

      it "returns the character before the position" do
        expect(output).to eq("b")
      end
    end
  end

  describe "#character_after" do
    let(:scanner) { described_class.new("abc") }
    let(:output) { scanner.character_after(position, length) }

    context "with a valid following character" do
      let(:position) { 0 }
      let(:length) { 1 }

      it "returns the character after the position" do
        expect(output).to eq("b")
      end
    end

    context "when the offset exceeds the string length" do
      let(:position) { 2 }
      let(:length) { 1 }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  describe "#escaped_single_quote?" do
    let(:scanner) { described_class.new(source) }

    context "with two consecutive single quotes" do
      let(:source) { "''rest" }

      it "returns true" do
        expect(scanner.escaped_single_quote?).to be true
      end
    end

    context "with a single quote followed by a different character" do
      let(:source) { "'rest" }

      it "returns false" do
        expect(scanner.escaped_single_quote?).to be false
      end
    end
  end

  describe "#escaped_double_quote?" do
    let(:scanner) { described_class.new(source) }

    context "with two consecutive double quotes" do
      let(:source) { '""rest' }

      it "returns true" do
        expect(scanner.escaped_double_quote?).to be true
      end
    end

    context "with a double quote followed by a different character" do
      let(:source) { '"rest' }

      it "returns false" do
        expect(scanner.escaped_double_quote?).to be false
      end
    end
  end

  ############################################################################
  ## Complex Operations
  ############################################################################

  describe "#find_matching_parenthesis" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.find_matching_parenthesis(opening_position) }

    context "with simple parentheses" do
      let(:source) { "(abc)" }
      let(:opening_position) { 0 }

      it "returns the position of the closing parenthesis" do
        expect(output).to eq(4)
      end
    end

    context "with nested parentheses" do
      let(:source) { "(a (b) c)" }
      let(:opening_position) { 0 }

      it "returns the position of the outermost closing parenthesis" do
        expect(output).to eq(8)
      end
    end

    context "with a string literal containing a parenthesis" do
      let(:source) { "('a)b')" }
      let(:opening_position) { 0 }

      it "ignores parentheses inside the string literal" do
        expect(output).to eq(6)
      end
    end

    context "with a quoted identifier containing a parenthesis" do
      let(:source) { '("a)b")' }
      let(:opening_position) { 0 }

      it "ignores parentheses inside the quoted identifier" do
        expect(output).to eq(6)
      end
    end

    context "with a sentinel inside parentheses" do
      let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
      let(:source) { "(#{sentinel})" }
      let(:opening_position) { 0 }

      it "skips over the sentinel" do
        expect(output).to eq(source.length - 1)
      end
    end

    context "without a matching closing parenthesis" do
      let(:source) { "(abc" }
      let(:opening_position) { 0 }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with a non-zero opening position" do
      let(:source) { "prefix (inner)" }
      let(:opening_position) { 7 }

      it "finds the match relative to the opening position" do
        expect(output).to eq(13)
      end
    end

    context "when called" do
      let(:source) { "(abc)" }
      let(:opening_position) { 0 }

      before { output }

      it "does not mutate the scanner position" do
        expect(scanner.position).to eq(0)
      end
    end
  end

  describe "#read_identifier!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.read_identifier! }

    context "with a simple unquoted identifier" do
      let(:source) { "users rest" }

      before { output }

      it "returns the identifier" do
        expect(output).to eq("users")
      end

      it "advances past the identifier" do
        expect(scanner.position).to eq(5)
      end
    end

    context "with a double-quoted identifier" do
      let(:source) { '"My Table" rest' }

      before { output }

      it "returns the quoted identifier including quotes" do
        expect(output).to eq('"My Table"')
      end

      it "advances past the closing quote" do
        expect(scanner.position).to eq(10)
      end
    end

    context "with a double-quoted identifier containing escaped quotes" do
      let(:source) { '"col""name" rest' }

      it "returns the full quoted identifier" do
        expect(output).to eq('"col""name"')
      end
    end

    context "with leading whitespace" do
      let(:source) { "  users" }

      it "skips whitespace and returns the identifier" do
        expect(output).to eq("users")
      end
    end

    context "with an empty source" do
      let(:source) { "" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with only whitespace remaining" do
      let(:source) { "   " }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  ############################################################################
  ## Convenience Methods
  ############################################################################

  describe "#scan_quoted_or_sentinel!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.scan_quoted_or_sentinel! }

    context "when at a sentinel" do
      let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
      let(:source) { "#{sentinel} rest" }

      it "consumes and returns the sentinel" do
        expect(output).to eq(sentinel)
      end
    end

    context "when at a single-quoted string" do
      let(:source) { "'hello' rest" }

      it "consumes and returns the quoted string" do
        expect(output).to eq("'hello'")
      end
    end

    context "when at a double-quoted identifier" do
      let(:source) { '"col" rest' }

      it "consumes and returns the quoted identifier" do
        expect(output).to eq('"col"')
      end
    end

    context "when at a dollar-quoted string" do
      let(:source) { "$$body$$ rest" }

      it "consumes and returns the dollar-quoted string" do
        expect(output).to eq("$$body$$")
      end
    end

    context "when at a regular character" do
      let(:source) { "abc" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end
  end

  describe "#skip_quoted_or_sentinel!" do
    let(:scanner) { described_class.new(source) }
    let(:output) { scanner.skip_quoted_or_sentinel! }

    context "when inside a single-quoted string" do
      let(:source) { "'ab'" }

      before do
        scanner.enter_single_quote!
        output
      end

      it "returns true" do
        expect(output).to be true
      end

      it "advances through the quoted character" do
        expect(scanner.position).to eq(2)
      end
    end

    context "when inside a double-quoted identifier" do
      let(:source) { '"ab"' }

      before do
        scanner.enter_double_quote!
        output
      end

      it "returns true" do
        expect(output).to be true
      end

      it "advances through the quoted character" do
        expect(scanner.position).to eq(2)
      end
    end

    context "when at a sentinel" do
      let(:sentinel) { "#{SqlBeautifier::CommentParser::SENTINEL_PREFIX}0#{SqlBeautifier::CommentParser::SENTINEL_SUFFIX}" }
      let(:source) { sentinel }

      before { output }

      it "returns true" do
        expect(output).to be true
      end

      it "advances past the sentinel" do
        expect(scanner.position).to eq(sentinel.length)
      end
    end

    context "when at a dollar-quoted string" do
      let(:source) { "$$body$$ rest" }

      before { output }

      it "returns true" do
        expect(output).to be true
      end

      it "advances past the dollar-quoted string" do
        expect(scanner.position).to eq(8)
      end
    end

    context "when at a regular character" do
      let(:source) { "abc" }

      before { output }

      it "returns false" do
        expect(output).to be false
      end

      it "does not advance" do
        expect(scanner.position).to eq(0)
      end
    end
  end
end
