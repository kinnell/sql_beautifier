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

from    users

where   active = true

order by name
```

Single-word keywords are lowercased and padded so their clause bodies start at an 8-character column. Multi-word clauses such as `order by` and `group by`, and short clauses like `limit`, use a single space between the keyword and the clause body instead of padding. Each clause is separated by a blank line. Multi-column SELECT lists place each column on its own line with continuation indentation.

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

from    users

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

from    users

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

from    users

where   name = 'O''Brien' and status = 'Active'
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

from    users
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
