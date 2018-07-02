# Mysql_Framework

[![Build Status](https://travis-ci.org/Sage/mysql_framework.svg?branch=master)](https://travis-ci.org/Sage/mysql_framework)
[![Maintainability](https://api.codeclimate.com/v1/badges/36068a1f03ea88d08b86/maintainability)](https://codeclimate.com/github/Sage/mysql_framework/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/36068a1f03ea88d08b86/test_coverage)](https://codeclimate.com/github/Sage/mysql_framework/test_coverage)
[![Gem Version](https://badge.fury.io/rb/mysql_framework.svg)](https://badge.fury.io/rb/mysql_framework)

Welcome to Mysql_Framework, this is a light weight framework that provides managers to help with interacting with mysql

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mysql_framework'
```

## Usage

### Environment Variables

* `MYSQL_HOST` - MySQL Host
* `MYSQL_PORT` - MySQL Port
* `MYSQL_DATABASE` - MySQL database name
* `MYSQL_USERNAME` - MySQL username
* `MYSQL_PASSWORD` - MySQL password
* `MYSQL_PARTITIONS` - The number of partitions where a table is partitioned (default: `500`)
* `REDIS_URL` - The URL for redis - used for managing locks for DB migrations

### Migration Scripts

Migration scripts need to be in the following format:

```ruby
class CreateDemoTable < MysqlFramework::Scripts::Base
  def initialize
    @identifier = 201806021520 # 15:20 02/06/2018
  end

  def apply
   mysql_connector.query("
      CREATE TABLE IF NOT EXISTS `#{database_name}`.`demo` (
        `id` CHAR(36) NOT NULL,
        `name` VARCHAR(255) NULL,
        `created_at` DATETIME NOT NULL,
        `updated_at` DATETIME NOT NULL,
        PRIMARY KEY (`id`)
      )")
  end

  def rollback
    mysql_connector.query("DROP TABLE IF EXISTS `#{database_name}`.`demo`")
  end

  def tags
    [DemoTable::NAME]
  end
end
```

#### #initialize

The initialize method should set the `@identifier` value, which should be a timestamp

```ruby
@identifier = 201806021520 # 15:20 02/06/2018
```

#### #apply

The `apply` method should action the migration. An instance of the `MysqlFramework::Connector` is
available as `mysql_connector` to use.

#### #rollback

The `rollback` method should action the migration. An instance of the `MysqlFramework::Connector`
is available as `mysql_connector` to use.

#### #tags

Tags are used for when we want to specify which migrations to run based on a tag. This is useful
for tests where you don't need to run all migrations to assert something is working or not.

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
connector.query("SELECT * FROM gems")
```

Options can be provided to override the defaults as follows:

```ruby
options = {
  host:      ENV.fetch('MYSQL_HOST'),
  port:      ENV.fetch('MYSQL_PORT'),
  database:  ENV.fetch('MYSQL_DATABASE'),
  username:  ENV.fetch('MYSQL_USERNAME'),
  password:  ENV.fetch('MYSQL_PASSWORD'),
  reconnect: true
}
MysqlFramework::Connector.new(options)
```

#### #check_out

Check out a client from the connection pool

```ruby
client = connector.check_out
```

#### #check_in

Check in a client to the connection pool

```ruby
client = connector.check_out
# ...
connector.check_in(client)
```

#### #with_client

Called with a block. The method checks out a client from the pool and yields it to the block. Finally it ensures that the client is always checked back into the pool.

```ruby
connector.with_client do |client|
  client.query('SELECT * FROM gems')
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

#### #query

This method is called to execute a query without having to worry about obtaining a client

```ruby
connector.query('SELECT * FROM versions')
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
  host:      ENV.fetch('MYSQL_HOST'),
  port:      ENV.fetch('MYSQL_PORT'),
  database:  ENV.fetch('MYSQL_DATABASE'),
  username:  ENV.fetch('MYSQL_USERNAME'),
  password:  ENV.fetch('MYSQL_PASSWORD'),
  reconnect: true
}
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
```

### MysqlFramework::SqlTable

A representation of a MySQL table.

```ruby
MysqlFramework::SqlTable.new('gems')
```

### Configuring Logs

As a default, `MysqlFramework` will log to `STDOUT`. You can provide your own logger using the `set_logger` method:

```ruby
MysqlFramework.set_logger(Logger.new('development.log'))
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sage/mysql_framework. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

This gem is available as open source under the terms of the [MIT licence](LICENSE).

Copyright (c) 2018 Sage Group Plc. All rights reserved.
