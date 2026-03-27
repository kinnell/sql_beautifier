# Changelog

## [X.X.X] - YYYY-MM-DD

- Update `bin/ci` and `bin/release` to use new formatting functions
- Add `--quiet` flag to `bin/ci` to suppress output
- Add `--dry-run` flag to `bin/release` to perform a dry run of the release process

## [0.1.0] - 2026-03-26

- Initial release
- Formats SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT clauses
- Lowercase keywords with 8-character column alignment
- Multi-column SELECT with continuation indentation
- Parenthesis and string-literal aware tokenization
- Normalizes whitespace and handles quoted identifiers
