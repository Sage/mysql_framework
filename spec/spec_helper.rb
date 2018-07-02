require 'simplecov'
SimpleCov.start do
  add_filter 'spec/'
end

ENV['MYSQL_DATABASE']   ||= 'test_database'
ENV['MYSQL_HOST']       ||= '127.0.0.1'
ENV['MYSQL_PARTITIONS'] ||= '5'
ENV['MYSQL_PASSWORD']   ||= ''
ENV['MYSQL_PORT']       ||= '3306'
ENV['MYSQL_USERNAME']   ||= 'root'
ENV['REDIS_URL']        ||= 'redis://127.0.0.1:6379'

require 'bundler'
require 'mysql_framework'
require 'securerandom'

require_relative 'support/scripts/create_test_table'
require_relative 'support/scripts/create_demo_table'
require_relative 'support/tables/test'
require_relative 'support/tables/demo'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

client = Mysql2::Client.new({
  host:      ENV.fetch('MYSQL_HOST'),
  port:      ENV.fetch('MYSQL_PORT'),
  username:  ENV.fetch('MYSQL_USERNAME'),
  password:  ENV.fetch('MYSQL_PASSWORD'),
})
client.query("DROP DATABASE IF EXISTS `#{ENV.fetch('MYSQL_DATABASE')}`;")
client.query("CREATE DATABASE `#{ENV.fetch('MYSQL_DATABASE')}`;")

connector = MysqlFramework::Connector.new
connector.query("DROP TABLE IF EXISTS `#{ENV.fetch('MYSQL_DATABASE')}`.`gems`")
connector.query("CREATE TABLE `#{ENV.fetch('MYSQL_DATABASE')}`.`gems` (
                  `id` CHAR(36) NOT NULL,
                  `name` VARCHAR(255) NULL,
                  `author` VARCHAR(255) NULL,
                  `created_at` DATETIME,
                  `updated_at` DATETIME,
                  PRIMARY KEY (`id`)
               )")
