# frozen_string_literal: true

module SqlBeautifier
  class Configuration
    DEFAULTS = {
      keyword_case: :lower,
      keyword_column_width: 8,
      indent_spaces: 4,
      clause_spacing_mode: :compact,
      table_name_format: :pascal_case,
      inline_group_threshold: 0,
      alias_strategy: :initials,
      trailing_semicolon: true,
      removable_comment_types: :none,
    }.freeze

    COMMENT_TYPES = %i[inline separate_line blocks].freeze

    attr_accessor :keyword_case
    attr_accessor :keyword_column_width
    attr_accessor :indent_spaces
    attr_accessor :clause_spacing_mode
    attr_accessor :table_name_format
    attr_accessor :inline_group_threshold
    attr_accessor :alias_strategy
    attr_accessor :trailing_semicolon
    attr_accessor :removable_comment_types

    def initialize
      reset!
    end

    def reset!
      DEFAULTS.each do |key, value|
        public_send(:"#{key}=", value)
      end
    end
  end
end
