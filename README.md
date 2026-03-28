# SqlBeautifier

Opinionated PostgreSQL SQL formatter.

## Requirements

- Ruby >= 3.2.0

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sql_beautifier"
```

And then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install sql_beautifier
```

## Usage

### Basic Formatting

```ruby
SqlBeautifier.call("SELECT id, name, email FROM users WHERE active = true ORDER BY name")
```

Produces:

```sql
select  id,
        name,
        email

from    Users u

where   active = true

order by name
```

Single-word keywords are lowercased and padded so their clause bodies start at an 8-character column. Multi-word clauses such as `order by` and `group by`, and short clauses like `limit`, use a single space between the keyword and the clause body instead of padding. Clause spacing is compact by default for simple one-column / one-table / one-condition queries, and otherwise uses blank lines between top-level clauses. Multi-column SELECT lists place each column on its own line with continuation indentation. Table names are PascalCased and automatically aliased.

### Table Aliasing

Tables are automatically aliased using their initials. Underscore-separated table names use the first letter of each segment:

| Table Name                 | PascalCase                 | Alias |
| -------------------------- | -------------------------- | ----- |
| `users`                    | `Users`                    | `u`   |
| `active_storage_blobs`     | `Active_Storage_Blobs`     | `asb` |
| `person_event_invitations` | `Person_Event_Invitations` | `pei` |

All `table.column` references throughout the query are replaced with `alias.column`:

```ruby
SqlBeautifier.call("SELECT users.id, users.name FROM users WHERE users.active = true")
```

Produces:

```sql
select  u.id,
        u.name

from    Users u

where   u.active = true
```

When two tables produce the same initials, a counter is appended for disambiguation (e.g. `u1`, `u2`).

### JOINs

JOIN clauses are formatted on continuation-indented lines with PascalCase table names and aliases. Multi-condition JOINs place additional conditions on further-indented lines:

```ruby
SqlBeautifier.call(<<~SQL)
  SELECT users.id, orders.total, products.name
  FROM users
  INNER JOIN orders ON orders.user_id = users.id
  INNER JOIN products ON products.id = orders.product_id
  WHERE users.active = true AND orders.total > 100
  ORDER BY orders.total DESC
SQL
```

Produces:

```sql
select  u.id,
        o.total,
        p.name

from    Users u
        inner join Orders o on o.user_id = u.id
        inner join Products p on p.id = o.product_id

where   u.active = true
        and o.total > 100

order by o.total desc
```

Supported join types: `inner join`, `left join`, `right join`, `full join`, `left outer join`, `right outer join`, `full outer join`, `cross join`.

### DISTINCT and DISTINCT ON

`DISTINCT` is placed on the `select` line as a modifier, with columns on continuation lines:

```ruby
SqlBeautifier.call("SELECT DISTINCT id, name, email FROM users")
```

Produces:

```sql
select  distinct
        id,
        name,
        email

from    Users u
```

`DISTINCT ON` preserves the full expression:

```ruby
SqlBeautifier.call("SELECT DISTINCT ON (user_id) id, name FROM events")
```

Produces:

```sql
select  distinct on (user_id)
        id,
        name

from    Events e
```

### WHERE and HAVING Conditions

Multiple conditions in WHERE and HAVING clauses are formatted with each condition on its own line:

```ruby
SqlBeautifier.call("SELECT * FROM users WHERE active = true AND role = 'admin' AND created_at > '2024-01-01'")
```

Produces:

```sql
select  *

from    Users u

where   active = true
        and role = 'admin'
        and created_at > '2024-01-01'
```

Parenthesized condition groups are expanded to multiple lines with indentation:

```ruby
SqlBeautifier.call("SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')")
```

Produces:

```sql
select  *

from    Users u

where   active = true
        and (
            role = 'admin'
            or role = 'moderator'
        )
```

### GROUP BY and HAVING

```ruby
SqlBeautifier.call(<<~SQL)
  SELECT status, count(*)
  FROM users
  GROUP BY status
  HAVING count(*) > 5
SQL
```

Produces:

```sql
select  status,
        count(*)

from    Users u

group by status

having  count(*) > 5
```

### LIMIT

```ruby
SqlBeautifier.call("SELECT id FROM users ORDER BY created_at DESC LIMIT 25")
```

Produces:

```sql
select  id
from    Users u
order by created_at desc
limit 25
```

### String Literals

Case is preserved inside single-quoted string literals, and escaped quotes (`''`) are handled correctly:

```ruby
SqlBeautifier.call("SELECT * FROM users WHERE name = 'O''Brien' AND status = 'Active'")
```

Produces:

```sql
select  *

from    Users u

where   name = 'O''Brien'
        and status = 'Active'
```

### Double-Quoted Identifiers

Double-quoted PostgreSQL identifiers are normalized by lowercasing their contents. If the resulting identifier can be safely represented as an unquoted PostgreSQL identifier, the surrounding quotes are removed; otherwise, the quotes are preserved and only the contents are lowercased:

```ruby
SqlBeautifier.call('SELECT "User_Id", "Full_Name" FROM "Users"')
```

Produces:

```sql
select  user_id,
        full_name

from    Users u
```

### Subqueries

Subqueries are automatically detected and recursively formatted with indentation:

```ruby
SqlBeautifier.call("SELECT id FROM users WHERE id IN (SELECT user_id FROM orders WHERE total > 100)")
```

Produces:

```sql
select  id
from    Users u
where   id in (
            select  user_id
            from    Orders o
            where   total > 100
        )
```

Nested subqueries increase indentation at each level.

### Comments and Semicolons

SQL comments (`--` line comments and `/* */` block comments) and trailing semicolons are automatically stripped during normalization. Comments inside string literals are preserved:

```ruby
SqlBeautifier.call("SELECT id /* primary key */ FROM users -- main table\nWHERE active = true;")
```

Produces:

```sql
select  id
from    Users u
where   active = true
```

### Configuration

Customize formatting behavior with `SqlBeautifier.configure`:

```ruby
SqlBeautifier.configure do |config|
  config.keyword_case = :upper
  config.keyword_column_width = 10
  config.indent_spaces = 4
  config.clause_spacing_mode = :spacious
  config.table_name_format = :lowercase
  config.inline_group_threshold = 80
  config.alias_strategy = :none
end
```

Reset to defaults:

```ruby
SqlBeautifier.reset_configuration!
```

#### `keyword_case`

Controls the case of SQL keywords in the output. Default: `:lower`.

- `:lower` — lowercases all keywords (`select`, `from`, `where`, `inner join`, etc.)
- `:upper` — uppercases all keywords (`SELECT`, `FROM`, `WHERE`, `INNER JOIN`, etc.)

#### `keyword_column_width`

Sets the column width for single-word keyword alignment. Keywords shorter than this width are right-padded with spaces so clause bodies start at this column position. Default: `8`.

For example, with the default width of 8, `select` (6 chars) gets 2 spaces of padding, `where` (5 chars) gets 3 spaces, and `from` (4 chars) gets 4 spaces. Multi-word keywords like `order by` and `group by` use a single space instead of padding.

#### `indent_spaces`

Number of spaces used for indentation within subqueries and CTE bodies. Each nesting level adds this many spaces of indentation. Default: `4`.

#### `clause_spacing_mode`

Controls whether blank lines are inserted between top-level clauses. Default: `:compact`.

- `:compact` — omits blank lines when the query is simple (single SELECT column, single FROM table with no JOINs, at most one WHERE condition, and only basic clauses like `select`, `from`, `where`, `order by`, `limit`). Complex queries automatically get blank lines regardless.
- `:spacious` — always inserts blank lines between every top-level clause.

#### `table_name_format`

Controls how table names are formatted in the output. Default: `:pascal_case`.

- `:pascal_case` — capitalizes each underscore-separated segment (`users` → `Users`, `active_storage_blobs` → `Active_Storage_Blobs`)
- `:lowercase` — keeps table names lowercase as-is

#### `inline_group_threshold`

Maximum character length for a parenthesized condition group to remain on a single line. Groups whose inline representation exceeds this length are expanded to multiple lines with indented conditions. Default: `0` (always expand).

Set to a positive integer to allow short groups to stay inline. For example, with a threshold of `80`, the group `(role = 'admin' or role = 'moderator')` would stay on one line since it's under 80 characters.

#### `alias_strategy`

Controls automatic table aliasing in FROM and JOIN clauses. Default: `:initials`.

- `:initials` — generates aliases from the first letter of each underscore-separated segment (`users` → `u`, `active_storage_blobs` → `asb`). When two tables produce the same initials, a counter is appended for disambiguation (`u1`, `u2`). All `table.column` references throughout the query are replaced with `alias.column`.
- `:none` — disables automatic aliasing. Explicit aliases written in the SQL are still preserved.
- Callable — provide a proc/lambda that receives the table name and returns a custom alias string:

```ruby
SqlBeautifier.configure do |config|
  config.alias_strategy = ->(table_name) { "t_#{table_name[0..2]}" }
end
```

### Callable Interface

`SqlBeautifier.call` is the public API, making it a valid callable for Rails `normalizes` and anywhere a proc-like object is expected:

```ruby
class Query < ApplicationRecord
  normalizes :sql, with: SqlBeautifier
end
```

## Development

After checking out the repo, run:

```bash
bin/setup
```

Run the test suite:

```bash
rake test
```

Run the linter:

```bash
rake lint
```

Run the full CI suite (tests + linting):

```bash
rake
```

Start an interactive console with the gem loaded:

```bash
bin/console
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kinnell/sql_beautifier.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
