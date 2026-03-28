# frozen_string_literal: true

module SqlBeautifier
  class CommentRestorer
    def self.call(formatted_sql, comment_map)
      return formatted_sql if comment_map.empty?

      new(formatted_sql, comment_map).call
    end

    def initialize(formatted_sql, comment_map)
      @formatted_sql = formatted_sql
      @comment_map = comment_map
    end

    def call
      result = @formatted_sql

      @comment_map.each do |index, entry|
        sentinel = "#{CommentStripper::SENTINEL_PREFIX}#{index}#{CommentStripper::SENTINEL_SUFFIX}"

        result = begin
          case entry[:type]
          when :blocks
            restore_block_comment(result, sentinel, entry[:text])
          when :separate_line
            restore_separate_line_comment(result, sentinel, entry[:text])
          when :inline
            restore_inline_comment(result, sentinel, entry[:text])
          else
            result
          end
        end
      end

      result
    end

    private

    def restore_block_comment(sql, sentinel, comment_text)
      sql.sub(sentinel, comment_text)
    end

    def restore_separate_line_comment(sql, sentinel, comment_text)
      sql.sub(%r{#{Regexp.escape(sentinel)}[ \n]?}, "#{comment_text}\n")
    end

    def restore_inline_comment(sql, sentinel, comment_text)
      pattern = %r{ ?#{Regexp.escape(sentinel)}([^\n]*)}
      sql.sub(pattern) do
        trailing_content = Regexp.last_match(1)

        if trailing_content.strip.empty?
          " #{comment_text}"
        else
          "#{trailing_content.strip} #{comment_text}"
        end
      end
    end
  end
end
