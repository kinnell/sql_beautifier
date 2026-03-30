# Changelog

## [X.X.X] - YYYY-MM-DD

## [0.9.2] - 2026-03-30

- Fix derived tables (subqueries in `FROM` clauses) losing their content during formatting — `TableRegistry#parse_references` used a regex split that did not respect parenthesis depth, causing JOIN keywords inside derived table subqueries to be treated as top-level boundaries
- Add derived table support to `TableReference` — segments starting with `(` are parsed as derived tables, preserving the full expression and extracting the alias from text after the closing `)`
- Extract `find_all_top_level_join_positions` and `find_earliest_top_level_join_keyword` into `Tokenizer` for shared use by `Clauses::From` and `TableRegistry`
- Improve subquery indentation for `FROM`-line subqueries — derived tables now align with keyword column width, matching the existing behavior for `WHERE`-line subqueries
- Fix aliasless derived tables in `FROM` clauses raising `NoMethodError` or receiving malformed auto-generated aliases — lookup now falls back to the full derived-table expression when no alias is present and alias assignment skips aliasless derived tables

## [0.9.1] - 2026-03-29

## [0.9.0] - 2026-03-29

- Add DML statement formatting for `INSERT`, `UPDATE`, and `DELETE` — each statement type is routed to a dedicated entity class (`InsertQuery`, `UpdateQuery`, `DeleteQuery`) following the `Base` + `parse`/`render` pattern
- Add `INSERT INTO ... VALUES` formatting with aligned column lists and multi-row value support
- Add `INSERT INTO ... SELECT` formatting with automatic delegation of the SELECT portion to the existing formatter pipeline
- Add `INSERT ... ON CONFLICT` and `INSERT ... RETURNING` clause support
- Add `UPDATE ... SET` formatting with comma-separated assignment alignment and optional `FROM` and `WHERE` clauses
- Add `DELETE FROM` formatting with optional `USING`, `WHERE`, and `RETURNING` clauses
- Extract shared `render_where` and `render_returning` methods into `DmlRendering` module, included by `InsertQuery`, `UpdateQuery`, and `DeleteQuery`
- Fix `InsertQuery` accepting malformed `VALUES` clause with no value tuples — empty rows from `scan_value_rows` are now treated as a parse failure
- Fix `DeleteQuery` silently dropping table aliases (e.g. `DELETE FROM users u WHERE u.id = 1` rendered without the `u` alias, producing invalid SQL) — aliases (with or without `AS`) are now captured and included in the formatted output
- Fix `DeleteQuery` mis-parsing `DELETE FROM ONLY <table>` — `ONLY` was read as the table name; the parser now bails out for unsupported modifiers
- Fix `InsertQuery` silently dropping unrecognized trailing text after VALUES tuples (e.g. `VALUES (1) foo` would drop `foo`) — remaining text must start with `ON CONFLICT` or `RETURNING`, otherwise the parser bails out
- Fix `DeleteQuery` silently dropping unrecognized text between table/alias and clause keywords — the parser now validates remaining text starts with a known clause keyword (`USING`, `WHERE`, `RETURNING`)
- Fix `InsertQuery` silently dropping trailing commas after VALUES tuples (e.g. `VALUES (1),`) — a comma not followed by another tuple is now treated as a parse failure

## [0.8.0] - 2026-03-29

- Add compound query support for set operators (`UNION`, `UNION ALL`, `INTERSECT`, `INTERSECT ALL`, `EXCEPT`, `EXCEPT ALL`) — top-level set operator boundaries are detected via `Scanner`, each segment is independently formatted through the `Formatter` pipeline, and operators appear on their own line with blank-line separation
- Introduce `CompoundQuery` entity class with `parse`/`render` following the `Base` + `dry-initializer` pattern established by `CteQuery` and `CreateTableAs`
- Add trailing clause handling for compound queries — `ORDER BY` and `LIMIT` after the final segment are extracted and rendered separately below the last formatted segment
- Fix `StatementSplitter` incorrectly splitting compound queries at the second `SELECT` — set operator keywords at depth 0 now suppress statement boundary detection for the following `SELECT`
- Add `SET_OPERATORS` constant to `Constants` (longest-first order for greedy matching)

## [0.7.0] - 2026-03-29

- Introduce `Query` entity encapsulating parsed clauses, depth, table registry, compact detection, and subquery formatting — `Formatter` delegates clause assembly and rendering to `Query`, and `SubqueryFormatter` is eliminated
- Introduce `CteQuery` and `CteDefinition` entities replacing `CteFormatter` — CTE parsing produces structured objects that render themselves
- Introduce `CreateTableAs` entity replacing `CreateTableAsFormatter` — structured object with modifier, if-not-exists, table name, body query, and suffix
- Introduce `Condition` tree model replacing flat `[conjunction, text]` pairs — parsed into leaf and group nodes with recursive rendering; eliminates `ConditionFormatter`
- Extract `Scanner` class consolidating duplicated character-by-character scanning logic across seven modules
- Consolidate `CommentStripper` and `CommentRestorer` into `CommentParser`
- Introduce `TableReference` and `Join` entities — `Clauses::From` delegates join rendering to `Join#render`; `TableRegistry` holds `TableReference` objects instead of raw hashes
- Introduce `Expression` entity for SELECT list items and `SortExpression` entity for ORDER BY items
- Introduce `Comment` entity with `content`, `type`, and `renderable` attributes

## [0.6.0] - 2026-03-28

- **Breaking**: comments are now preserved by default. Set `removable_comment_types = :all` to restore previous behavior of stripping all comments
- Add `removable_comment_types` configuration option (default: `:none`) — controls which SQL comment types are stripped during formatting. Accepts `:none`, `:all`, or an array of specific types (`:inline`, `:separate_line`, `:blocks`)
- Add multi-statement support — input containing multiple statements (separated by `;` or concatenated) is split and formatted independently
- Add `trailing_semicolon` configuration option (default: `true`) — automatically appends `;` to each formatted statement
- Add per-call configuration overrides via `SqlBeautifier.call(value, trailing_semicolon: false)` — overrides take precedence over global config for the duration of the call
- Change `inline_group_threshold` default from `100` to `0` — parenthesized condition groups are now always expanded to multiple lines
- Fix `StatementSplitter` incorrectly splitting `INSERT INTO ... SELECT` as two separate statements
- Fix inline comments after a trailing semicolon (e.g. `SELECT 1; -- done`) being silently dropped during formatting
- Fix infinite loop in `Normalizer#consume_sentinel!` when a malformed sentinel prefix has no closing `*/`
- Fix `CommentStripper#resolve_removal_set` returning `nil` for unrecognized `removable_types` values — now raises `ArgumentError` with a descriptive message
- Fix `CommentStripper#resolve_removal_set` silently accepting invalid entries in Array-typed `removable_types` (e.g. `[:inlne]`) — now validates each element against known comment types
- Fix `CommentStripper` not inserting token-separating whitespace around sentinels when preserving block comments between adjacent tokens (e.g. `SELECT/*comment*/id`)
- Strengthen end-to-end specs with exact full-output assertions and add coverage for JOINs, subqueries, CTEs, CREATE TABLE AS, DISTINCT, complex WHERE conditions, and configuration variations

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
