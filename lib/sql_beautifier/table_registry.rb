# frozen_string_literal: true

module SqlBeautifier
  class TableRegistry
    attr_reader :table_map

    def initialize(from_content)
      @from_content = from_content
      @table_map = {}
      build!
    end

    def alias_for(table_name)
      @table_map[table_name]
    end

    def apply_aliases(text)
      output = +""
      position = 0

      while position < text.length
        character = text[position]

        case character
        when Constants::SINGLE_QUOTE
          position = copy_string_literal!(text, position, output)
        when Constants::DOUBLE_QUOTE
          position = copy_quoted_identifier!(text, position, output)
        else
          replacement = find_table_replacement_at(text, position)

          if replacement
            table_name, table_alias = replacement

            output << "#{table_alias}."
            position += table_name.length + 1
          else
            output << character
            position += 1
          end
        end
      end

      output
    end

    private

    def build!
      table_entries = extract_table_entries(@from_content)
      initials_occurrence_counts = count_initials_occurrences(table_entries)
      used_aliases = []

      assign_aliases!(table_entries, initials_occurrence_counts, used_aliases)
      @tables_by_descending_length = @table_map.keys.sort_by { |name| -name.length }.freeze
    end

    def count_initials_occurrences(table_entries)
      occurrence_counts = Hash.new(0)

      table_entries.each do |table_entry|
        next if table_entry[:explicit_alias]

        table_name = table_entry[:table_name]
        occurrence_counts[table_initials(table_name)] += 1
      end

      occurrence_counts
    end

    def assign_aliases!(table_entries, initials_occurrence_counts, used_aliases)
      duplicate_initials_counts = Hash.new(0)
      collision_counts = Hash.new(0)

      table_entries.each do |table_entry|
        table_name = table_entry[:table_name]
        explicit_alias = table_entry[:explicit_alias]

        if explicit_alias
          @table_map[table_name] = explicit_alias
          used_aliases << explicit_alias
          next
        end

        initials = table_initials(table_name)
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

        @table_map[table_name] = candidate_alias
        used_aliases << candidate_alias
      end
    end

    def copy_string_literal!(text, position, output)
      output << text[position]
      position += 1

      while position < text.length
        character = text[position]
        output << character

        if Tokenizer.escaped_single_quote?(text, position)
          position += 1
          output << text[position]
        elsif character == Constants::SINGLE_QUOTE
          return position + 1
        end

        position += 1
      end

      position
    end

    def copy_quoted_identifier!(text, position, output)
      output << text[position]
      position += 1

      while position < text.length
        character = text[position]
        output << character

        if Tokenizer.escaped_double_quote?(text, position)
          position += 1
          output << text[position]
        elsif character == Constants::DOUBLE_QUOTE
          return position + 1
        end

        position += 1
      end

      position
    end

    def find_table_replacement_at(text, position)
      return unless Tokenizer.word_boundary?(Tokenizer.character_before(text, position))

      @tables_by_descending_length.each do |table_name|
        next unless text[position, table_name.length + 1] == "#{table_name}."

        return [table_name, @table_map[table_name]]
      end

      nil
    end

    def table_initials(table_name)
      table_name.split("_").map { |segment| segment[0] }.join
    end

    def extract_table_entries(from_content)
      split_segments = from_content.strip.split(Constants::JOIN_KEYWORD_PATTERN)

      table_entries = []

      primary_segment = split_segments.shift.strip
      table_entries << extract_table_entry(primary_segment)

      split_segments.each_slice(2) do |_join_keyword, join_content|
        next unless join_content

        table_entries << extract_table_entry(join_content)
      end

      table_entries.compact
    end

    def extract_table_entry(segment_text)
      table_specification = table_specification_text(segment_text)
      table_name = Util.first_word(table_specification)
      return unless table_name

      {
        table_name: table_name,
        explicit_alias: extract_explicit_alias(table_specification),
      }
    end

    def table_specification_text(segment_text)
      on_keyword_position = Tokenizer.find_top_level_keyword(segment_text, "on")
      return segment_text.strip unless on_keyword_position

      segment_text[0...on_keyword_position].strip
    end

    def extract_explicit_alias(table_specification)
      words = table_specification.strip.split(Constants::WHITESPACE_REGEX)
      return nil if words.length < 2

      if words[1] == "as"
        words[2]
      else
        words[1]
      end
    end
  end
end
