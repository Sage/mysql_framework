# Mysql_Framework

[![RSpec](https://github.com/Sage/mysql_framework/actions/workflows/rspec.yml/badge.svg)](https://github.com/Sage/mysql_framework/actions/workflows/rspec.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/36068a1f03ea88d08b86/maintainability)](https://codeclimate.com/github/Sage/mysql_framework/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/36068a1f03ea88d08b86/test_coverage)](https://codeclimate.com/github/Sage/mysql_framework/test_coverage)
[![Gem Version](https://badge.fury.io/rb/mysql_framework.svg)](https://badge.fury.io/rb/mysql_framework)

Welcome to Mysql_Framework, this is a lightweight framework that provides managers to help with interacting with mysql.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mysql_framework'
```

## Usage

### Environment Variables

#### MySQL Connection Variables

* `MYSQL_HOST` - MySQL Host
* `MYSQL_PORT` - MySQL Port
* `MYSQL_DATABASE` - MySQL database name
* `MYSQL_USERNAME` - MySQL username
* `MYSQL_PASSWORD` - MySQL password

#### MySQL Timeout Variables

* `MYSQL_READ_TIMEOUT` - how long before connections time out when reading information from the DB (default: `30` seconds)
* `MYSQL_WRITE_TIMEOUT` - how long before connections time out when writing information to the DB (default: `10` seconds)

#### MySQL Connection Pooling Variables

* `MYSQL_CONNECTION_POOL_ENABLED` - enables/disables pooling (default: `false`)
* `MYSQL_MAX_POOL_SIZE` - how many connections should the pool be allowed to grow to (default: `5`)
* `MYSQL_POOL_TIMEOUT` - how long to wait for a pooled connection before timing out (default: `5` seconds)
* `MYSQL_POOL_IDLE_TIMEOUT` - how long a pooled connection can remain idle before being reaped (default: `300` seconds)
* `MYSQL_POOL_IDLE_REAP_TIME` - time interval between background thread checking for idle connections to reap (default: `60` seconds)

#### MySQL Migration Variables

* `MYSQL_MIGRATION_TABLE` - the name of the table that holds a record of applied migrations (default: `migration_script_history`)
* `MYSQL_MIGRATION_LOCK_TTL` - how long the tables should be locked for whilst performing migrations (default: `2000` / `2 seconds`)
* `MYSQL_MIGRATION_LOCK_MAX_ATTEMPTS` - how many times the lock manager should attempt to acquire the lock before failing (default: `300`)
* `MYSQL_MIGRATION_LOCK_RETRY_DELAY_S` - how long the lock manager should sleep between lock request attempts (default: `1 second`)
* `REDIS_URL` - The URL for redis - used for managing locks for DB migrations

#### Miscellaneous Variables

* `MYSQL_PARTITIONS` - if a table is partitioned, how many partitions should be created (default: `500`)

### Migration Scripts

Migration scripts need to be in the following format:

```ruby
class CreateDemoTable < MysqlFramework::Scripts::Base
  def initialize
    @identifier = 201806021520 # 15:20 02/06/2018
  end

  def apply(client)
   client.query(<<~SQL)
      CREATE TABLE IF NOT EXISTS `#{table_name}` (
        `id` CHAR(36) NOT NULL,
        `name` VARCHAR(255) NULL,
        `created_at` DATETIME NOT NULL,
        `updated_at` DATETIME NOT NULL,
        PRIMARY KEY (`id`)
      )
    SQL
  end

  def rollback(client)
    client.query(<<~SQL)
      DROP TABLE IF EXISTS `#{table_name}`
    SQL
  end

  def tags
    [table_name]
  end

  private

  def table_name
    DemoTable::NAME
  end
end
```

#### #initialize

The initialize method should set the `@identifier` value, which should be a timestamp:

```ruby
@identifier = 201806021520 # 15:20 02/06/2018
```

Make sure `@identifier` is an integer too, otherwise `MysqlFramework::Scripts::Manager` may struggle to determine which are your pending migrations.

#### #apply

The `apply` method should action the migration. An instance of `Mysql2::Client` is
available as `client` to use.

#### #rollback

The `rollback` method should action the migration. An instance of `Mysql2::Client` is
available as `client` to use.

#### #tags

Tags are used for when we want to specify which migrations to run based on a tag. This is useful
for tests where you don't need to run all migrations to assert something is working or not.

#### Running migrations

Use the `MysqlFramework::Scripts::Manager#execute` method to run all pending migrations.

### MysqlFramework::Scripts::Table

Used to register tables. This is used as part of the `all_tables` method in the script manager for
awareness of tables to drop.

```ruby
class DemoTable
  extend MysqlFramework::Scripts::Table

  NAME = 'demo'

  register_table NAME
end
```

### MysqlFramework::Connector

The connector deals with the connection pooling of `MySQL2::Client` instances, providing a wrapper for queries and transactions.

```ruby
connector = MysqlFramework::Connector.new
connector.setup
connector.query(<<~SQL)
  SELECT * FROM gems
SQL
```

Options can be provided to override the defaults as follows:

```ruby
options = {
  host: ENV.fetch('MYSQL_HOST'),
  port: ENV.fetch('MYSQL_PORT'),
  database: ENV.fetch('MYSQL_DATABASE'),
  username: ENV.fetch('MYSQL_USERNAME'),
  password: ENV.fetch('MYSQL_PASSWORD'),
  reconnect: true
}
MysqlFramework::Connector.new(options)
```

#### #setup

Sets up connection pooling using `connection_pool` with `ENV['MYSQL_MAX_POOL_SIZE']` and `ENV['MYSQL_POOL_TIMEOUT']`. Connections are created lazily by the pool when first needed.

```ruby
connector.setup
```

#### #dispose

Closes pooled `Mysql2::Client` connections and removes the pool. Intended as a clean-up method to be used on process fork shutdown.

```ruby
connector.dispose
```

#### #check_out

Checks out a `Mysql2::Client` instance from the pool, sanitizes it, and returns it.
When pooling is disabled, it returns a newly created client.

```ruby
client = connector.check_out
```

#### #check_in

Checks a client back in to the pool.
When pooling is disabled, it closes the provided client.

```ruby
client = connector.check_out
# ...
connector.check_in(client)
```

#### #with_client

Called with a block. The method obtains a client (from the pool when enabled), yields it to the block, and guarantees cleanup.

When pooling is enabled, it uses the pool lifecycle (`ConnectionPool#with`) and supports optional discarding of the current pooled connection:

```ruby
connector.with_client(discard_current_pool_connection: true) do |client|
  # use client
end
```

When pooling is disabled, it creates a fresh client for the block and closes it afterwards.

```ruby
connector.with_client do |client|
  client.query(<<~SQL)
    SELECT * FROM gems
  SQL
end
```

**Warning: re-entrant connections within the same thread**

The `connection_pool` gem implements thread-local connection tracking. When a thread already holds a connection via `with_client` (or `check_out`), any nested call to `with_client` or `check_out` on the **same thread** returns the **same connection** — it does not check out a second one from the pool.

This means that if you fire an async query on a connection and then attempt to run a second query (e.g. via `run_query` or `connector.query`) from within the same `with_client` block, the nested call will receive the already-checked-out connection. Sanitization will then fail with:

```
Connection sanitization failed: This connection is still waiting for a result,
try again once you have the result
```

It can optionally accept an existing client to avoid starting new connections in the middle of a transaction. This can be used to ensure that a series of queries are wrapped by the same transaction.

```ruby
connector.with_client(existing_client) do |client|
  client.query(<<~SQL)
    SELECT * FROM gems
  SQL
end
```

#### #execute

This method is called when executing a prepared statement where value substitution is required:

```ruby
insert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .values(SecureRandom.uuid,'mysql_framework','sage',Time.now,Time.now)

connector.execute(insert)
```

It can optionally accept an existing client to avoid checking out a new client.

```ruby
insert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .values(SecureRandom.uuid,'mysql_framework','sage',Time.now,Time.now)

connector.execute(insert, existing_client)
```

#### #query

This method is called to execute a query without having to worry about obtaining a client

```ruby
connector.query(<<~SQL)
  SELECT * FROM versions
SQL
```

It can optionally accept an existing client to avoid checking out a new client.

```ruby
connector.query(<<~SQL, existing_client)
  SELECT * FROM versions
SQL
```

#### #transaction

This method requires a block and yields a client obtained from the pool. It wraps the yield in a `BEGIN` and `COMMIT` query. If an exception is raised then it will submit a `ROLLBACK` query and re-raise the exception.

```ruby
insert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .values(SecureRandom.uuid,'mysql_framework','sage',Time.now,Time.now)

connector.transaction do |client|
  client.query(insert)
end
```

#### #default_options

The default options used to initialise MySQL2::Client instances:

```ruby
{
  host: ENV.fetch('MYSQL_HOST'),
  port: ENV.fetch('MYSQL_PORT'),
  database: ENV.fetch('MYSQL_DATABASE'),
  username: ENV.fetch('MYSQL_USERNAME'),
  password: ENV.fetch('MYSQL_PASSWORD'),
  reconnect: true,
  read_timeout: Integer(ENV.fetch('MYSQL_READ_TIMEOUT', 30)),
  write_timeout: Integer(ENV.fetch('MYSQL_WRITE_TIMEOUT', 10))
}
```

### MysqlFramework::Stats::AwsMetricPublisher

Publishes connection-pool metrics (`size`, `available`, `idle`) to AWS CloudWatch on a configurable interval via a background thread.

**Setup sequence** — the connector must be set up before the publisher is started:

```ruby
connector = MysqlFramework::Connector.new
connector.setup  # must come first

publisher = MysqlFramework::Stats::AwsMetricPublisher.new(
  connector: connector,
  publish_interval: 300  # seconds, default
)
publisher.start
```

On shutdown, stop the publisher before disposing the connector:

```ruby
publisher.stop
connector.dispose
```

#### Customising CloudWatch dimensions and namespace

Use `MysqlFramework::Stats::DimensionMap` to configure the CloudWatch namespace and dimensions. Each attribute falls back to the corresponding environment variable when not set explicitly:

| Attribute | ENV fallback | CloudWatch dimension |
|---|---|---|
| `service_name` | `SERVICE_NAME` | `ServiceName` |
| `application` | `APPLICATION` | `Application` |
| `environment` | `ENVIRONMENT` | `Environment` |
| `landscape` | `LANDSCAPE` | `Landscape` |
| `namespace` | `AWS_METRICS_NAMESPACE` | (namespace, default: `MysqlFramework`) |

```ruby
dimension_map = MysqlFramework::Stats::DimensionMap.new(
  service_name: 'my-service',
  application:  'my-app',
  environment:  'production',
  landscape:    'us-east',
  namespace:    'MyCompany/MySQL'
)

publisher = MysqlFramework::Stats::AwsMetricPublisher.new(
  connector:        connector,
  dimension_map:    dimension_map,
  publish_interval: 60
)
publisher.start
```

### MysqlFramework::SqlCondition

A representation of a MySQL Condition for a column. Created automatically by SqlColumn

```ruby
# eq condition
SqlCondition.new(column: 'name', comparison: '=', value: 'mysql_framework')
```

### MysqlFramework::SqlColumn

A representation of a MySQL column within a table. Created automatically by SqlTable.

```ruby
SqlCondition.new(table: 'gems', column: 'name')
```

### MysqlFramework::SqlQuery

A representation of a MySQL Query.

```ruby
gems = MysqlFramework::SqlTable.new('gems')
guid = SecureRandom.uuid

# Insert Query
insert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .values(guid,'mysql_framework','sage',Time.now,Time.now)

# Update Query
update = MysqlFramework::SqlQuery.new.update(gems)
  .set(updated_at: Time.now)
  .where(gems[:id].eq(guid))

# Delete Query
delete = MysqlFramework::SqlQuery.new.delete
  .from(gems)
  .where(gems[:id].eq(guid))

# Bulk Values Query
bulk_insert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .bulk_values([[guid,'mysql_framework','sage',Time.now,Time.now], [guid,'mysql_framework','sage',Time.now,Time.now]])

# Bulk On Duplicate Query
bulk_upsert = MysqlFramework::SqlQuery.new.insert(gems)
  .into(gems[:id],gems[:name],gems[:author],gems[:created_at],gems[:updated_at])
  .bulk_values([[guid,'mysql_framework','sage',Time.now,Time.now], [guid,'mysql_framework','sage',Time.now,Time.now]])
  .on_duplicate(gems[:id] => nil,gems[:name] => nil,gems[:author] => nil,gems[:created_at] => nil,gems[:updated_at] => nil)
```

### MysqlFramework::SqlTable

A representation of a MySQL table.

```ruby
MysqlFramework::SqlTable.new('gems')
```

### Configuring Logs

As a default, `MysqlFramework` will log to `STDOUT`. You can provide your own logger using the `logger=` method:

```ruby
MysqlFramework.logger = Logger.new('development.log')
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sage/mysql_framework. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Testing (with Docker)
A compose file is provided for running specs.

### Setup
```
docker-compose up -d
docker-compose exec test-runner bash
# Once the shell opens in the container
bundle
```

### Running specs
```
bundle exec rspec
```
Exit out of the shell when finished.

### Cleanup
```
docker-compose down
```

## License

This gem is available as open source under the terms of the [MIT licence](LICENSE).

Copyright (c) 2018 Sage Group Plc. All rights reserved.
