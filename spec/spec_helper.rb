# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  add_filter 'spec/'
end

ENV['RACK_ENV'] = 'test'

ENV['MYSQL_START_POOL_SIZE'] ||= '1'
ENV['MYSQL_MAX_POOL_SIZE'] ||= '5'
ENV['MYSQL_PARTITIONS'] ||= '5'

ENV['MYSQL_HOST'] ||= '127.0.0.1'
ENV['MYSQL_PORT'] ||= '3306'
ENV['MYSQL_DATABASE'] ||= 'test_database'
ENV['MYSQL_USERNAME'] ||= 'root'
ENV['MYSQL_PASSWORD'] ||= ''

ENV['REDIS_URL'] ||= 'redis://127.0.0.1:6379'

require 'bundler'
require 'mysql_framework'
require 'securerandom'

require_relative 'support/scripts/create_test_table'
require_relative 'support/scripts/create_demo_table'
require_relative 'support/scripts/create_test_proc'
require_relative 'support/tables/test'
require_relative 'support/tables/demo'
require_relative 'support/fixtures'

MysqlFramework::Support::Fixtures.execute

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
