# frozen_string_literal: true

module SqlBeautifier
  class TableRegistry
    attr_reader :references

    def initialize(from_content)
      @from_content = from_content
      @alias_strategy = SqlBeautifier.config_for(:alias_strategy)
      @references = []
      @references_by_name = {}
      build!
    end

    def alias_for(table_name)
      @references_by_name[table_name]&.alias_name
    end

    def reference_for(table_name)
      @references_by_name[table_name]
    end

    def table_map
      @references_by_name.transform_values(&:alias_name)
    end

    def apply_aliases(text)
      return text if @references_by_name.empty?

      scanner = Scanner.new(text)
      output = +""

      until scanner.finished?
        case scanner.current_char
        when Constants::SINGLE_QUOTE
          output << scanner.consume_single_quoted_string!
        when Constants::DOUBLE_QUOTE
          output << scanner.consume_double_quoted_identifier!
        else
          replacement = find_table_replacement_at(text, scanner.position, scanner)

          if replacement
            table_name, table_alias = replacement

            output << "#{table_alias}."
            scanner.advance!(table_name.length + 1)
          else
            output << scanner.current_char
            scanner.advance!
          end
        end
      end

      output
    end

    private

    def build!
      @references = parse_references(@from_content)
      @references.each { |reference| @references_by_name[reference.name] = reference }

      assign_computed_aliases! unless @alias_strategy == :none

      aliased_names = @references_by_name.select { |_name, reference| reference.alias_name }.keys
      @tables_by_descending_length = aliased_names.sort_by { |name| -name.length }.freeze
    end

    def assign_computed_aliases!
      initials_occurrence_counts = count_initials_occurrences
      duplicate_initials_counts = Hash.new(0)
      collision_counts = Hash.new(0)
      used_aliases = []

      @references.each do |reference|
        if reference.explicit_alias
          @references_by_name[reference.name] = reference
          used_aliases << reference.explicit_alias
          next
        end

        initials = table_initials(reference.name)
        duplicate_initials_counts[initials] += 1 if initials_occurrence_counts[initials] > 1

        candidate_alias = begin
          if initials_occurrence_counts[initials] > 1
            "#{initials}#{duplicate_initials_counts[initials]}"
          else
            initials
          end
        end

        if used_aliases.include?(candidate_alias)
          collision_counts[initials] = [collision_counts[initials], duplicate_initials_counts[initials]].max

          loop do
            collision_counts[initials] += 1
            candidate_alias = "#{initials}#{collision_counts[initials]}"
            break unless used_aliases.include?(candidate_alias)
          end
        end

        reference.assign_alias!(candidate_alias)
        used_aliases << candidate_alias
      end
    end

    def count_initials_occurrences
      occurrence_counts = Hash.new(0)

      @references.each do |reference|
        next if reference.explicit_alias

        occurrence_counts[table_initials(reference.name)] += 1
      end

      occurrence_counts
    end

    def find_table_replacement_at(text, position, scanner)
      return unless scanner.word_boundary?(scanner.character_before(position))

      @tables_by_descending_length.each do |table_name|
        next unless text[position, table_name.length + 1] == "#{table_name}."

        return [table_name, @references_by_name[table_name].alias_name]
      end

      nil
    end

    def table_initials(table_name)
      return @alias_strategy.call(table_name) if @alias_strategy.respond_to?(:call)

      table_name.split("_").map { |segment| segment[0] }.join
    end

    def parse_references(from_content)
      split_segments = from_content.strip.split(Constants::JOIN_KEYWORD_PATTERN)

      references = []

      primary_segment = split_segments.shift.strip
      references << TableReference.parse(primary_segment)

      split_segments.each_slice(2) do |_join_keyword, join_content|
        next unless join_content

        references << TableReference.parse(join_content)
      end

      references.compact
    end
  end
end
