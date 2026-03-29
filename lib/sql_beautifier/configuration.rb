# frozen_string_literal: true

module SqlBeautifier
  class Configuration < Base
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

    DEFAULTS.each_key do |key|
      option key, default: -> { DEFAULTS[key] }
      attr_writer key
    end

    def reset!
      DEFAULTS.each do |key, value|
        public_send(:"#{key}=", value)
      end
    end
  end
end
