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

Single-word keywords are lowercased and padded so their clause bodies start at an 8-character column. Multi-word clauses such as `order by` and `group by`, and short clauses like `limit`, use a single space between the keyword and the clause body instead of padding. Each clause is separated by a blank line. Multi-column SELECT lists place each column on its own line with continuation indentation. Table names are PascalCased and automatically aliased.

### Table Aliasing

Tables are automatically aliased using their initials. Underscore-separated table names use the first letter of each segment:

| Table Name | PascalCase | Alias |
| --- | --- | --- |
| `users` | `Users` | `u` |
| `active_storage_blobs` | `Active_Storage_Blobs` | `asb` |
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

Short parenthesized groups stay inline:

```ruby
SqlBeautifier.call("SELECT * FROM users WHERE active = true AND (role = 'admin' OR role = 'moderator')")
```

Produces:

```sql
select  *

from    Users u

where   active = true
        and (role = 'admin' or role = 'moderator')
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
