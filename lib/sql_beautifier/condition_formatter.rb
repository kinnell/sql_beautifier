# frozen_string_literal: true

module SqlBeautifier
  module ConditionFormatter
    module_function

    def format(text, indent_width:)
      conditions = Tokenizer.split_top_level_conditions(text)
      return text.strip if conditions.length <= 1 && !parse_condition_group(conditions.dig(0, 1))

      conditions = flatten_same_conjunction_groups(conditions)
      indentation = " " * indent_width
      lines = []

      conditions.each_with_index do |(conjunction, condition_text), index|
        unwrapped_condition = unwrap_single_condition(condition_text)
        formatted_condition_text = format_single_condition(unwrapped_condition, indent_width: indent_width)

        line = begin
          if index.zero?
            "#{indentation}#{formatted_condition_text}"
          else
            "#{indentation}#{conjunction} #{formatted_condition_text}"
          end
        end

        lines << line
      end

      lines.join("\n")
    end

    def flatten_same_conjunction_groups(conditions)
      return conditions if conditions.length <= 1

      outer_conjunction = conditions[1]&.first
      return conditions unless outer_conjunction
      return conditions unless conditions.drop(1).all? { |pair| pair[0] == outer_conjunction }

      flattened_conditions = []

      conditions.each do |conjunction, condition_text|
        inner_conditions = parse_condition_group(condition_text)

        if inner_conditions && flattenable_into_conjunction?(inner_conditions, outer_conjunction)
          flatten_inner_conditions_into!(flattened_conditions, inner_conditions, conjunction, outer_conjunction)
        else
          flattened_conditions << [conjunction, condition_text]
        end
      end

      flattened_conditions
    end

    def rebuild_inline(inner_conditions)
      parts = inner_conditions.map.with_index do |(conjunction, condition_text), index|
        index.zero? ? condition_text : "#{conjunction} #{condition_text}"
      end

      "(#{parts.join(' ')})"
    end

    def unwrap_single_condition(condition)
      output = condition.strip

      while Tokenizer.outer_parentheses_wrap_all?(output)
        inner_content = Util.strip_outer_parentheses(output)
        inner_conditions = Tokenizer.split_top_level_conditions(inner_content)
        break if inner_conditions.length > 1

        output = inner_content
      end

      output
    end

    def parse_condition_group(condition_text)
      return unless condition_text

      trimmed_condition = condition_text.strip
      return unless Tokenizer.outer_parentheses_wrap_all?(trimmed_condition)

      inner_content = Util.strip_outer_parentheses(trimmed_condition)
      inner_conditions = Tokenizer.split_top_level_conditions(inner_content)
      return unless inner_conditions.length > 1

      inner_conditions
    end

    def format_single_condition(condition_text, indent_width:)
      inner_conditions = parse_condition_group(condition_text)
      return condition_text unless inner_conditions

      inline_version = rebuild_inline(inner_conditions)
      return inline_version if inline_version.length <= Constants::INLINE_GROUP_THRESHOLD

      inner_content = Util.strip_outer_parentheses(condition_text.strip)
      formatted_inner_content = format(inner_content, indent_width: indent_width + 4)
      indentation = " " * indent_width

      "(\n#{formatted_inner_content}\n#{indentation})"
    end

    def flattenable_into_conjunction?(inner_conditions, outer_conjunction)
      inner_conjunction = inner_conditions[1]&.first

      inner_conjunction == outer_conjunction && inner_conditions.drop(1).all? { |pair| pair[0] == outer_conjunction }
    end

    def flatten_inner_conditions_into!(flattened_conditions, inner_conditions, conjunction, outer_conjunction)
      inner_conditions.each_with_index do |inner_pair, inner_index|
        condition_pair = begin
          if flattened_conditions.empty?
            [nil, inner_pair[1]]
          elsif inner_index.zero?
            [conjunction || outer_conjunction, inner_pair[1]]
          else
            [outer_conjunction, inner_pair[1]]
          end
        end

        flattened_conditions << condition_pair
      end
    end
  end
end
