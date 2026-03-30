# frozen_string_literal: true

module SqlBeautifier
  module Constants
    CLAUSE_KEYWORDS = [
      "select",
      "from",
      "where",
      "group by",
      "having",
      "order by",
      "limit",
    ].freeze

    JOIN_KEYWORDS = [
      "inner join",
      "left outer join",
      "right outer join",
      "full outer join",
      "left join",
      "right join",
      "full join",
      "cross join",
    ].freeze

    JOIN_KEYWORDS_BY_LENGTH = JOIN_KEYWORDS.sort_by { |keyword| -keyword.length }.freeze
    JOIN_KEYWORD_PATTERN = %r{\b(#{JOIN_KEYWORDS.map { |keyword| Regexp.escape(keyword) }.join('|')})\b}i

    SET_OPERATORS = [
      "intersect all",
      "except all",
      "union all",
      "intersect",
      "except",
      "union",
    ].freeze

    CONJUNCTIONS = %w[and or].freeze
    BETWEEN_KEYWORD = "between"

    OPEN_PARENTHESIS = "("
    CLOSE_PARENTHESIS = ")"
    COMMA = ","

    LATERAL_PREFIX_PATTERN = %r{\Alateral\s+}i

    WHITESPACE_REGEX = %r{\s+}
    WHITESPACE_CHARACTER_REGEX = %r{\s}
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'
    ESCAPED_DOUBLE_QUOTE = '""'
  end
end
