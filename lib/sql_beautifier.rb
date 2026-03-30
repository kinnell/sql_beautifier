# frozen_string_literal: true

require "active_support/core_ext/object/blank"

require_relative "sql_beautifier/version"
require_relative "sql_beautifier/constants"
require_relative "sql_beautifier/util"
require_relative "sql_beautifier/base"
require_relative "sql_beautifier/configuration"
require_relative "sql_beautifier/types"

require_relative "sql_beautifier/scanner"
require_relative "sql_beautifier/comment"
require_relative "sql_beautifier/comment_parser"
require_relative "sql_beautifier/normalizer"
require_relative "sql_beautifier/tokenizer"
require_relative "sql_beautifier/statement_splitter"
require_relative "sql_beautifier/table_reference"
require_relative "sql_beautifier/table_registry"
require_relative "sql_beautifier/join"
require_relative "sql_beautifier/case_expression"
require_relative "sql_beautifier/expression"
require_relative "sql_beautifier/sort_expression"
require_relative "sql_beautifier/condition"
require_relative "sql_beautifier/cte_definition"
require_relative "sql_beautifier/cte_query"
require_relative "sql_beautifier/create_table_as"
require_relative "sql_beautifier/compound_query"
require_relative "sql_beautifier/dml_rendering"
require_relative "sql_beautifier/insert_query"
require_relative "sql_beautifier/update_query"
require_relative "sql_beautifier/delete_query"
require_relative "sql_beautifier/clauses/base"
require_relative "sql_beautifier/clauses/condition_clause"
require_relative "sql_beautifier/clauses/select"
require_relative "sql_beautifier/clauses/from"
require_relative "sql_beautifier/clauses/where"
require_relative "sql_beautifier/clauses/group_by"
require_relative "sql_beautifier/clauses/order_by"
require_relative "sql_beautifier/clauses/having"
require_relative "sql_beautifier/clauses/limit"
require_relative "sql_beautifier/query"
require_relative "sql_beautifier/formatter"
require_relative "sql_beautifier/statement_assembler"

module SqlBeautifier
  class Error < StandardError; end

  module_function

  def call(value, config = {})
    return unless value.present?

    with_configuration(config) do
      StatementAssembler.call(value)
    end
  end

  def configuration
    @configuration ||= Configuration.new
  end

  def configure
    yield configuration
  end

  def config_for(key)
    overrides = Thread.current[:sql_beautifier_config]
    return overrides[key] if overrides&.key?(key)

    configuration.public_send(key)
  end

  def reset_configuration!
    @configuration = Configuration.new
  end

  def with_configuration(config)
    raise ArgumentError, "Expected a Hash for configuration overrides, got #{config.class}" unless config.is_a?(Hash)

    return yield if config.empty?

    previous = Thread.current[:sql_beautifier_config]
    validate_configuration_keys!(config)
    Thread.current[:sql_beautifier_config] = config
    yield
  ensure
    Thread.current[:sql_beautifier_config] = previous if config.is_a?(Hash) && config.any?
  end

  def validate_configuration_keys!(config)
    invalid_keys = config.keys - Configuration::DEFAULTS.keys
    raise ArgumentError, "Unknown configuration keys: #{invalid_keys.join(', ')}" if invalid_keys.any?
  end
end
