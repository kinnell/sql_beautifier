# Changelog

## [X.X.X] - YYYY-MM-DD

## [0.5.0] - 2026-03-28

- Add support for Create Table As (CTA) formatting

## [0.4.0] - 2026-03-27

- Add CTE (Common Table Expression) formatting with recursive indentation

## [0.3.0] - 2026-03-27

- Add configuration system with `SqlBeautifier.configure` block and `SqlBeautifier.reset_configuration!`
- Add configurable keyword case (`:lower` / `:upper`), keyword column width, indent spaces, table name format (`:pascal_case` / `:lowercase`), inline group threshold, and alias strategy (`:initials` / `:none` / callable)
- Add semicolon stripping in normalizer (trailing `;` removed before formatting)
- Add comment stripping in normalizer (`--` line comments and `/* */` block comments, string-aware)
- Add subquery formatting with recursive indentation (`(select ...)` expanded to multiline)

## [0.2.0] - 2026-03-27

- Add JOIN support (inner, left, right, full outer, cross) with formatted continuation lines
- Add automatic table aliasing using initials (e.g. `users` → `u`, `active_storage_blobs` → `asb`)
- Add PascalCase table name formatting (e.g. `users` → `Users`, `user_sessions` → `User_Sessions`)
- Add `table.column` → `alias.column` replacement across full output
- Add DISTINCT and DISTINCT ON support in SELECT clause
- Add AND/OR condition formatting in WHERE and HAVING clauses with per-line indentation
- Add parenthesized condition group handling (inline when short, expanded when long)

## [0.1.4] - 2026-03-26

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
