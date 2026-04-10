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

order by name;
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

where   u.active = true;
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

order by o.total desc;
```

Supported join types: `inner join`, `left join`, `right join`, `full join`, `left outer join`, `right outer join`, `full outer join`, `cross join`. The `LATERAL` modifier is supported with `inner join lateral` and `left join lateral` for lateral subqueries.

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

from    Users u;
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

from    Events e;
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
        and created_at > '2024-01-01';
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
        );
```

`IN` value lists with multiple items are expanded to one item per line. Single-item lists and `IN (SELECT ...)` subqueries are left inline:

```ruby
SqlBeautifier.call("SELECT id FROM users WHERE status IN ('active', 'pending', 'banned')")
```

Produces:

```sql
select  id
from    Users u
where   status in (
            'active',
            'pending',
            'banned'
        );
```

Redundant parentheses are removed, including after `NOT`:

```ruby
SqlBeautifier.call("SELECT id FROM users WHERE NOT ((active = true OR role = 'guest')) AND verified = true")
```

Produces:

```sql
select  id

from    Users u

where   not (active = true or role = 'guest')
        and verified = true;
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

having  count(*) > 5;
```

### CASE Expressions

Both searched (`CASE WHEN ... THEN ... END`) and simple (`CASE expr WHEN value THEN ... END`) forms are formatted with multiline indentation. Inner `when`/`else`/`end` lines are indented relative to the `case` keyword:

```ruby
SqlBeautifier.call("SELECT id, CASE WHEN status = 'active' THEN 'Active' WHEN status = 'pending' THEN 'Pending' ELSE 'Unknown' END AS status_label, name FROM users")
```

Produces:

```sql
select  id,
        case
            when status = 'active' then 'Active'
            when status = 'pending' then 'Pending'
            else 'Unknown'
        end as status_label,
        name

from    Users u;
```

Simple CASE places the operand on the `case` line:

```ruby
SqlBeautifier.call("SELECT CASE u.role WHEN 'admin' THEN 'Administrator' WHEN 'user' THEN 'Standard User' ELSE 'Guest' END AS role_label FROM users")
```

Produces:

```sql
select  case u.role
            when 'admin' then 'Administrator'
            when 'user' then 'Standard User'
            else 'Guest'
        end as role_label

from    Users u;
```

CASE expressions inside parenthesized function calls are preserved inline:

```ruby
SqlBeautifier.call("SELECT COALESCE(CASE WHEN x > 0 THEN x ELSE NULL END, 0) AS safe_x FROM users")
```

Produces:

```sql
select  coalesce(case when x > 0 then x else null end, 0) as safe_x
from    Users u;
```

CASE expressions also work in WHERE/HAVING conditions and UPDATE SET assignments. Nested CASE blocks are recursively formatted with increased indentation. Short CASE expressions can remain inline when below the `inline_group_threshold`.

### LIMIT

```ruby
SqlBeautifier.call("SELECT id FROM users ORDER BY created_at DESC LIMIT 25")
```

Produces:

```sql
select  id
from    Users u
order by created_at desc
limit 25;
```

### INSERT

`INSERT INTO ... VALUES` statements format with an indented column list and aligned value rows:

```ruby
SqlBeautifier.call(<<~SQL)
  INSERT INTO users (id, name, email)
  VALUES (1, 'Alice', 'alice@example.com'),
         (2, 'Bob', 'bob@example.com')
SQL
```

Produces:

```sql
insert into Users (
    id,
    name,
    email
)
values  (1, 'Alice', 'alice@example.com'),
        (2, 'Bob', 'bob@example.com');
```

`INSERT INTO ... SELECT` delegates the SELECT portion to the full formatter pipeline:

```ruby
SqlBeautifier.call("INSERT INTO users (id, name) SELECT id, name FROM temp_users WHERE active = true")
```

Produces:

```sql
insert into Users (
    id,
    name
)

select  id,
        name

from    Temp_Users tu

where   active = true;
```

PostgreSQL `ON CONFLICT` and `RETURNING` clauses are supported:

```ruby
SqlBeautifier.call("INSERT INTO users (id, name) VALUES (1, 'Alice') ON CONFLICT (id) DO NOTHING RETURNING id")
```

Produces:

```sql
insert into Users (
    id,
    name
)
values  (1, 'Alice')
on conflict (id) do nothing
returning id;
```

### UPDATE

`UPDATE ... SET` formats with aligned assignments and optional `FROM` and `WHERE` clauses:

```ruby
SqlBeautifier.call("UPDATE users SET name = 'Alice', email = 'alice@example.com' WHERE id = 1")
```

Produces:

```sql
update  Users
set     name = 'Alice',
        email = 'alice@example.com'
where   id = 1;
```

PostgreSQL join-style `UPDATE ... FROM ... WHERE` is supported:

```ruby
SqlBeautifier.call("UPDATE users SET name = accounts.name FROM accounts WHERE users.account_id = accounts.id")
```

Produces:

```sql
update  Users
set     name = accounts.name
from    accounts
where   users.account_id = accounts.id;
```

### DELETE

`DELETE FROM` formats with standard clause layout:

```ruby
SqlBeautifier.call("DELETE FROM users WHERE status = 'inactive' AND last_login < '2024-01-01'")
```

Produces:

```sql
delete
from    Users
where   status = 'inactive'
        and last_login < '2024-01-01';
```

PostgreSQL `USING` and `RETURNING` clauses are supported:

```ruby
SqlBeautifier.call("DELETE FROM users USING accounts WHERE users.account_id = accounts.id RETURNING users.id")
```

Produces:

```sql
delete
from    Users
using   Accounts
where   users.account_id = accounts.id
returning users.id;
```

### DROP TABLE

`DROP TABLE` statements are recognized and formatted with proper keyword casing and table name formatting:

```ruby
SqlBeautifier.call("DROP TABLE IF EXISTS persons")
```

Produces:

```sql
drop table if exists Persons;
```

### CREATE TABLE (DDL)

`CREATE TABLE` statements with column definitions are recognized and formatted with proper keyword casing and table name formatting. Column definitions are preserved as-is:

```ruby
SqlBeautifier.call("CREATE TEMPORARY TABLE persons (id bigint)")
```

Produces:

```sql
create temporary table Persons (id bigint);
```

Modifiers (`TEMP`, `TEMPORARY`, `UNLOGGED`, `LOCAL`) and `IF NOT EXISTS` are supported.

### Set Operators (UNION, INTERSECT, EXCEPT)

Compound queries joined by set operators are detected and each segment is formatted independently. The operator keyword appears on its own line with blank-line separation:

```ruby
SqlBeautifier.call(<<~SQL)
  SELECT id, name FROM users WHERE active = true
  UNION ALL
  SELECT id, name FROM admins WHERE role = 'super'
SQL
```

Produces:

```sql
select  id,
        name

from    Users u

where   active = true

union all

select  id,
        name

from    Admins a

where   role = 'super';
```

Supported operators: `UNION`, `UNION ALL`, `INTERSECT`, `INTERSECT ALL`, `EXCEPT`, `EXCEPT ALL`. Multiple operators can be mixed in a single query. Trailing `ORDER BY` and `LIMIT` that apply to the compound result are rendered after the last segment:

```ruby
SqlBeautifier.call("SELECT id FROM users UNION ALL SELECT id FROM admins ORDER BY id LIMIT 10")
```

Produces:

```sql
select  id
from    Users u

union all

select  id
from    Admins a

order by id
limit 10;
```

Set operators inside parenthesized subqueries are handled correctly and do not split the outer query. Each segment is formatted with its own independent table registry, so alias collisions between segments are not a concern.

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
        and status = 'Active';
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

from    Users u;
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
        );
```

Nested subqueries increase indentation at each level.

Derived tables (subqueries in `FROM` clauses) are also supported — the subquery content is recursively formatted and the alias is preserved:

```ruby
SqlBeautifier.call("SELECT active_users.id FROM (SELECT id FROM users WHERE active = true) AS active_users")
```

Produces:

```sql
select  active_users.id
from    (
            select  id
            from    Users u
            where   active = true
        ) active_users;
```

### Trailing Semicolons

By default, each formatted statement ends with a `;`:

```ruby
SqlBeautifier.call("SELECT id FROM users WHERE active = true")
```

Produces:

```sql
select  id
from    Users u
where   active = true;
```

Disable with `config.trailing_semicolon = false` to omit the trailing `;`.

### Multiple Statements

Input containing multiple SQL statements is split and formatted independently. Statements can be separated by `;` or simply concatenated:

```ruby
SqlBeautifier.call("SELECT id FROM constituents; SELECT id FROM departments")
```

Produces:

```sql
select  id
from    Constituents c;

select  id
from    Departments d;
```

Concatenated statements without `;` are also detected:

```ruby
SqlBeautifier.call("SELECT id FROM constituents SELECT id FROM departments")
```

Produces the same output. Subqueries and CTE bodies are not mistakenly split.

### Comments

By default, SQL comments are preserved in formatted output. Line comments (`--`) and block comments (`/* */`) are classified by position and passed through formatting:

```ruby
SqlBeautifier.call("-- Base Query\nSELECT id /* primary key */ FROM users WHERE active = true")
```

Produces:

```sql
-- Base Query
select  id /* primary key */
from    Users u
where   active = true;
```

Configure `removable_comment_types` to control which comment types are stripped. See the `removable_comment_types` configuration option for details. Comments inside string literals are always preserved regardless of configuration.

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
  config.trailing_semicolon = false
  config.removable_comment_types = :all
end
```

Reset to defaults:

```ruby
SqlBeautifier.reset_configuration!
```

#### Per-Call Overrides

Pass configuration overrides directly to `SqlBeautifier.call` to override global settings for a single invocation:

```ruby
SqlBeautifier.call(query, trailing_semicolon: false, keyword_case: :upper)
```

Per-call overrides take precedence over the global `SqlBeautifier.configure` block. Any keys not included in the override hash fall back to the global configuration. The global configuration is never mutated. Unknown keys raise `ArgumentError`.

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

Maximum character length for a parenthesized condition group or CASE expression to remain on a single line. Groups and CASE expressions whose inline representation exceeds this length are expanded to multiple lines with indented contents. Default: `0` (always expand).

Set to a positive integer to allow short groups and CASE expressions to stay inline. For example, with a threshold of `80`, the group `(role = 'admin' or role = 'moderator')` and a short CASE like `case when x = 1 then 'yes' else 'no' end` would stay on one line since they're under 80 characters.

#### `trailing_semicolon`

Controls whether a trailing `;` is appended to each formatted statement. Default: `true`.

- `true` — appends `;` at the end of each statement
- `false` — omits the trailing `;`

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

#### `removable_comment_types`

Controls which SQL comment types are stripped during formatting. Default: `:none`.

- `:none` — preserves all comments in the formatted output
- `:all` — strips all comments (equivalent to `[:inline, :line, :blocks]`)
- Array of specific types — strips only the listed types, preserving the rest

The three comment types:

- `:line` — `--` comments on their own line (only whitespace before `--`), including banner-style dividers
- `:inline` — `--` comments at the end of a line that contains SQL
- `:blocks` — `/* ... */` block comments (single or multi-line)

```ruby
SqlBeautifier.configure do |config|
  config.removable_comment_types = [:inline, :blocks]
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
