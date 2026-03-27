# frozen_string_literal: true

require "active_support/core_ext/object/blank"

require_relative "sql_beautifier/version"
require_relative "sql_beautifier/constants"
require_relative "sql_beautifier/util"
require_relative "sql_beautifier/configuration"

require_relative "sql_beautifier/normalizer"
require_relative "sql_beautifier/tokenizer"
require_relative "sql_beautifier/table_registry"
require_relative "sql_beautifier/condition_formatter"
require_relative "sql_beautifier/subquery_formatter"
require_relative "sql_beautifier/cte_formatter"
require_relative "sql_beautifier/create_table_as_formatter"
require_relative "sql_beautifier/clauses/base"
require_relative "sql_beautifier/clauses/condition_clause"
require_relative "sql_beautifier/clauses/select"
require_relative "sql_beautifier/clauses/from"
require_relative "sql_beautifier/clauses/where"
require_relative "sql_beautifier/clauses/group_by"
require_relative "sql_beautifier/clauses/order_by"
require_relative "sql_beautifier/clauses/having"
require_relative "sql_beautifier/clauses/limit"
require_relative "sql_beautifier/formatter"

module SqlBeautifier
  class Error < StandardError; end

  module_function

  def call(value)
    return unless value.present?

    Formatter.call(value)
  end

  def configuration
    @configuration ||= Configuration.new
  end

  def configure
    yield configuration
  end

  def config_for(key)
    configuration.public_send(key)
  end

  def reset_configuration!
    @configuration = Configuration.new
  end
end
