# frozen_string_literal: true

RSpec.describe SqlBeautifier::Comment do
  describe "#initialize" do
    context "with valid attributes" do
      let(:comment) { described_class.new("-- hello", type: :inline) }

      it "stores the content" do
        expect(comment.content).to eq("-- hello")
      end

      it "stores the type" do
        expect(comment.type).to eq(:inline)
      end

      it "defaults renderable to true" do
        expect(comment).to be_renderable
      end
    end

    context "with renderable set to false" do
      let(:comment) { described_class.new("-- hello", type: :inline, renderable: false) }

      it "stores the renderable flag" do
        expect(comment).not_to be_renderable
      end
    end

    context "with an invalid type" do
      it "raises an ArgumentError" do
        expect { described_class.new("-- hello", type: :unknown) }.to raise_error(Dry::Types::ConstraintError)
      end
    end

    described_class::TYPES.each do |valid_type|
      context "with type :#{valid_type}" do
        let(:comment) { described_class.new("text", type: valid_type) }

        it "accepts the type" do
          expect(comment.type).to eq(valid_type)
        end
      end
    end
  end

  describe "#render" do
    let(:comment) { described_class.new("/* block */", type: :blocks) }

    it "returns the content" do
      expect(comment.render).to eq("/* block */")
    end
  end

  describe "CommentParser integration" do
    let(:removable_types) { :none }
    let(:output) { SqlBeautifier::CommentParser.call(sql, removable_types) }
    let(:comments) { output.comments }

    context "with an inline comment" do
      let(:sql) { "SELECT 1 -- inline" }

      it "produces a Comment with type :inline" do
        expect(comments.length).to eq(1)
        expect(comments.first.type).to eq(:inline)
      end

      it "stores the comment content" do
        expect(comments.first.content).to eq("-- inline")
      end

      it "marks the comment as renderable" do
        expect(comments.first).to be_renderable
      end
    end

    context "with a separate-line comment" do
      let(:sql) do
        <<~SQL.chomp
          -- header
          SELECT 1
        SQL
      end

      it "produces a Comment with type :line" do
        expect(comments.length).to eq(1)
        expect(comments.first.type).to eq(:line)
      end

      it "stores the comment content" do
        expect(comments.first.content).to eq("-- header")
      end
    end

    context "with a block comment" do
      let(:sql) { "SELECT /* block */ 1" }

      it "produces a Comment with type :blocks" do
        expect(comments.length).to eq(1)
        expect(comments.first.type).to eq(:blocks)
      end

      it "stores the comment content" do
        expect(comments.first.content).to eq("/* block */")
      end
    end

    context "with multiple comments" do
      let(:sql) do
        <<~SQL.chomp
          -- header
          SELECT /* block */ 1 -- inline
        SQL
      end

      it "produces one Comment per comment" do
        expect(comments.length).to eq(3)
      end

      it "preserves the comment order" do
        expect(comments.map(&:type)).to eq(%i[line blocks inline])
      end
    end

    context "with removable comment types" do
      let(:removable_types) { :all }
      let(:sql) { "SELECT 1 -- inline" }

      it "marks the comment as not renderable" do
        expect(comments.first).not_to be_renderable
      end
    end

    context "with selectively removable types" do
      let(:removable_types) { [:inline] }

      let(:sql) do
        <<~SQL.chomp
          -- header
          SELECT 1 -- inline
        SQL
      end

      it "marks only the matching type as not renderable" do
        line_comment = comments.find { |comment| comment.type == :line }
        inline_comment = comments.find { |comment| comment.type == :inline }

        expect(line_comment).to be_renderable
        expect(inline_comment).not_to be_renderable
      end
    end
  end
end
