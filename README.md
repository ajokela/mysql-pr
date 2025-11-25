# mysql-pr

A pure Ruby MySQL client library. No native extensions required.

[![CI](https://github.com/ajokela/mysql-pr/actions/workflows/ci.yml/badge.svg)](https://github.com/ajokela/mysql-pr/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/mysql-pr.svg)](https://badge.fury.io/rb/mysql-pr)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mysql-pr'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install mysql-pr
```

## Requirements

- Ruby 3.0 or higher
- MySQL 5.7+ or MySQL 8.0+

## Usage

### Basic Connection

```ruby
require 'mysql-pr'

# Connect to MySQL
my = MysqlPR.connect('hostname', 'username', 'password', 'database')

# Execute a query
result = my.query("SELECT id, name FROM users WHERE active = 1")
result.each do |id, name|
  puts "#{id}: #{name}"
end

# Close connection
my.close
```

### Prepared Statements

```ruby
# Using prepared statements (recommended for user input)
stmt = my.prepare('INSERT INTO users (name, email) VALUES (?, ?)')
stmt.execute('John Doe', 'john@example.com')

# Select with prepared statement
stmt = my.prepare('SELECT * FROM users WHERE id = ?')
stmt.execute(123)
stmt.each do |row|
  puts row.inspect
end
```

### Transactions

```ruby
my.autocommit(false)

begin
  my.query("INSERT INTO accounts (name) VALUES ('test')")
  my.query("UPDATE balances SET amount = amount - 100 WHERE id = 1")
  my.commit
rescue => e
  my.rollback
  raise e
end
```

### Connection Options

```ruby
my = MysqlPR.init
my.options(MysqlPR::OPT_CONNECT_TIMEOUT, 10)
my.options(MysqlPR::OPT_READ_TIMEOUT, 30)
my.options(MysqlPR::SET_CHARSET_NAME, 'utf8mb4')
my.connect('hostname', 'username', 'password', 'database')
```

### Escaping Strings

```ruby
# Class method (no connection required)
safe_string = MysqlPR.escape_string("O'Reilly")

# Instance method
safe_string = my.escape_string(user_input)
```

### SSL/TLS Connections

```ruby
my = MysqlPR.init

# Simple SSL (no certificate verification - for self-signed certs)
my.ssl_options = { verify: false }
my.connect('hostname', 'username', 'password', 'database')

# SSL with CA certificate verification
my.ssl_set(nil, nil, '/path/to/ca-cert.pem')
my.connect('hostname', 'username', 'password', 'database')

# SSL with client certificate
my.ssl_set(
  '/path/to/client-key.pem',
  '/path/to/client-cert.pem',
  '/path/to/ca-cert.pem'
)
my.connect('hostname', 'username', 'password', 'database')

# Check SSL status
puts my.ssl_enabled?  # => true
puts my.ssl_cipher    # => ["TLS_AES_256_GCM_SHA384", "TLSv1.3", 256, 256]
```

## Features

- Pure Ruby implementation - no compilation required
- MySQL protocol 4.1+ support
- **Full MySQL 8.0 support** including `caching_sha2_password` authentication
- **SSL/TLS encrypted connections** (TLS 1.2, 1.3)
- Prepared statements with parameter binding
- Multiple result sets
- Character set support with automatic encoding conversion
- Thread-safe connections

## Differences from mysql2 gem

This gem is a pure Ruby implementation, which means:

- **Pros**: No native compilation, works on any Ruby platform, easier to install
- **Cons**: Generally slower than native extensions for high-throughput applications

Choose `mysql-pr` when you need:
- Easy installation without native dependencies
- Compatibility with JRuby or other alternative Ruby implementations
- A lightweight MySQL client for simple applications

## Development

### Running Tests

Unit tests can be run without a MySQL server:

```bash
bundle exec rspec spec/unit spec/mysql
```

### Integration Tests with Docker

To run integration tests against a real MySQL server:

```bash
# Start MySQL container
docker compose up -d

# Run integration tests
./bin/test-with-docker

# Stop MySQL container when done
docker compose down
```

Or configure your own MySQL server using environment variables:

```bash
MYSQL_SERVER=localhost \
MYSQL_USER=root \
MYSQL_PASSWORD=secret \
MYSQL_DATABASE=test_for_mysql_ruby \
MYSQL_PORT=3306 \
bundle exec rspec spec/mysql_spec.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ajokela/mysql-pr.

## License

This gem is available under the Ruby License. See the LICENSE file for more details.

## Authors

- TOMITA Masahiro (tommy@tmtm.org) - Original author
- Alex Jokela (alex@camulus.com) - Current maintainer
