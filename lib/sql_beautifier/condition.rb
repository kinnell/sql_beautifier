# frozen_string_literal: true

module SqlBeautifier
  class Condition < Base
    NOT_PREFIX_PATTERN = %r{\Anot([[:space:]]+)}i

    option :conjunction, default: -> {}
    option :expression, default: -> {}
    option :children, default: -> {}

    def self.format(text, indent_width: 0)
      conditions = parse_all(text)
      return conditions.first.expression if conditions.length <= 1 && conditions.first&.leaf?

      render_all(conditions, indent_width: indent_width)
    end

    def self.parse_all(text)
      raw_pairs = Tokenizer.split_top_level_conditions(text)
      conditions = raw_pairs.map do |conjunction, condition_text|
        build(conjunction, condition_text)
      end

      flatten_same_conjunction_groups(conditions)
    end

    def self.render_all(conditions, indent_width:)
      indentation = Util.whitespace(indent_width)
      lines = []

      conditions.each_with_index do |condition, index|
        rendered = condition.render(indent_width: indent_width)

        line = begin
          if index.zero?
            "#{indentation}#{rendered}"
          else
            "#{indentation}#{condition.conjunction} #{rendered}"
          end
        end

        lines << line
      end

      lines.join("\n")
    end

    def leaf?
      @children.nil?
    end

    def group?
      !leaf?
    end

    def render(indent_width:)
      return InList.format_in_text(@expression, base_indent: indent_width) if leaf?

      inline_version = render_inline
      return inline_version if inline_version.length <= SqlBeautifier.config_for(:inline_group_threshold)

      inner_output = self.class.render_all(@children, indent_width: indent_width + 4)
      closing_indentation = Util.whitespace(indent_width)

      "(\n#{inner_output}\n#{closing_indentation})"
    end

    def self.build(conjunction, condition_text)
      unwrapped = unwrap_single_condition(condition_text)
      inner_conditions = parse_condition_group(unwrapped)

      if inner_conditions
        children = inner_conditions.map do |inner_conjunction, inner_text|
          build(inner_conjunction, inner_text)
        end

        new(conjunction: conjunction, children: children)
      else
        new(conjunction: conjunction, expression: unwrapped)
      end
    end

    def self.unwrap_single_condition(condition_text)
      output = condition_text.strip

      while Tokenizer.outer_parentheses_wrap_all?(output)
        inner_content = Util.strip_outer_parentheses(output)
        inner_conditions = Tokenizer.split_top_level_conditions(inner_content)
        break if inner_conditions.length > 1

        output = inner_content
      end

      unwrap_not_prefix_parens(output)
    end

    def self.unwrap_not_prefix_parens(text)
      prefix_match = text.match(NOT_PREFIX_PATTERN)
      return text unless prefix_match

      remainder = text[prefix_match[0].length..]

      unwrapped_remainder = remainder

      while Tokenizer.outer_parentheses_wrap_all?(unwrapped_remainder)
        inner_content = Util.strip_outer_parentheses(unwrapped_remainder)
        inner_conditions = Tokenizer.split_top_level_conditions(inner_content)
        break if inner_conditions.length > 1

        unwrapped_remainder = inner_content
      end

      return text if unwrapped_remainder == remainder

      "not #{unwrapped_remainder}"
    end

    def self.parse_condition_group(condition_text)
      return unless condition_text

      trimmed = condition_text.strip
      return unless Tokenizer.outer_parentheses_wrap_all?(trimmed)

      inner_content = Util.strip_outer_parentheses(trimmed)
      inner_conditions = Tokenizer.split_top_level_conditions(inner_content)
      return unless inner_conditions.length > 1

      inner_conditions
    end

    def self.flatten_same_conjunction_groups(conditions)
      return conditions if conditions.length <= 1

      outer_conjunction = conditions[1]&.conjunction
      return conditions unless outer_conjunction
      return conditions unless conditions.drop(1).all? { |condition| condition.conjunction == outer_conjunction }

      flattened = []

      conditions.each do |condition|
        if condition.group? && flattenable_into_conjunction?(condition, outer_conjunction)
          flatten_group_into!(flattened, condition, outer_conjunction)
        else
          flattened << condition
        end
      end

      flattened
    end

    def self.flattenable_into_conjunction?(condition, outer_conjunction)
      return false unless condition.group?

      inner_conjunction = condition.children[1]&.conjunction
      inner_conjunction == outer_conjunction && condition.children.drop(1).all? { |child| child.conjunction == outer_conjunction }
    end

    def self.flatten_group_into!(flattened, group_condition, outer_conjunction)
      group_condition.children.each_with_index do |child, inner_index|
        new_conjunction = begin
          if flattened.empty?
            nil
          elsif inner_index.zero?
            group_condition.conjunction || outer_conjunction
          else
            outer_conjunction
          end
        end

        flattened << new(conjunction: new_conjunction, expression: child.expression, children: child.children)
      end
    end

    protected

    def render_inline
      parts = @children.map.with_index do |child, index|
        rendered = child.leaf? ? child.expression : child.render_inline
        index.zero? ? rendered : "#{child.conjunction} #{rendered}"
      end

      "(#{parts.join(' ')})"
    end
  end
end
