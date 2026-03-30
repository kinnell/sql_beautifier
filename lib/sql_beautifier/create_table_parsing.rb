# frozen_string_literal: true

module SqlBeautifier
  module CreateTableParsing
    def self.extended(base)
      base.private_class_method :detect_modifier
      base.private_class_method :detect_if_not_exists?
      base.private_class_method :skip_past_if_not_exists!
    end

    def detect_modifier(scanner)
      Constants::TABLE_MODIFIERS.detect { |modifier| scanner.keyword_at?(modifier) }
    end

    def detect_if_not_exists?(scanner)
      return false unless scanner.keyword_at?("if")

      probe = Scanner.new(scanner.source, position: scanner.position)
      probe.skip_past_keyword!("if")
      return false unless probe.keyword_at?("not")

      probe.skip_past_keyword!("not")
      probe.keyword_at?("exists")
    end

    def skip_past_if_not_exists!(scanner)
      scanner.skip_past_keyword!("if")
      scanner.skip_past_keyword!("not")
      scanner.skip_past_keyword!("exists")
    end
  end
end
