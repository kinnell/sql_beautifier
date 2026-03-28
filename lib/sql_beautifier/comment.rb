# frozen_string_literal: true

module SqlBeautifier
  class Comment < Base
    TYPES = %i[
      inline
      line
      blocks
    ].freeze

    param :content
    option :type, type: Types::Coercible::Symbol.enum(*TYPES), default: -> { :line }
    option :renderable, type: Types::Bool, optional: true, default: -> { true }

    def renderable?
      @renderable
    end

    def render
      @content
    end
  end
end
