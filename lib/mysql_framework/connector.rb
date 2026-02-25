# frozen_string_literal: true

require 'active_record'
require 'active_record/connection_adapters/mysql2_adapter'

# Monkeypatch the MySQL2 adapter to return hashes with symbol keys by default
module MysqlFramework
  module Mysql2AdapterPatch
    def configure_connection
      super
      @raw_connection.query_options[:as] = :hash
      @raw_connection.query_options[:symbolize_keys] = true
      @raw_connection.query_options[:cast_booleans] = true
    end
  end
end

ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(MysqlFramework::Mysql2AdapterPatch)

module MysqlFramework
  class Connector
    def initialize(options = {})
      @options = default_options.merge(options)
      @connection_map = nil
      @map_mutex = Mutex.new
      @setup_mutex = Mutex.new
      @setup_complete = false
    end

    # This method is called to setup the ActiveRecord connection pool.
    def setup
      return if @setup_complete

      @setup_mutex.synchronize do
        return if @setup_complete

        ActiveRecord::Base.establish_connection(active_record_config)
        @connection_map = {}
        @setup_complete = true
      end
    end

    # This method is called to close all MySQL connections in the pool and dispose of the pool itself.
    def dispose
      return unless @setup_complete

      ActiveRecord::Base.connection_pool.disconnect!

      @map_mutex.synchronize do
        @connection_map.clear
      end

      @setup_complete = false
    end

    # This method is called to get the connection pool for this connector.
    def connections
      return nil unless @setup_complete

      ActiveRecord::Base.connection_pool
    end

    # This method is called to fetch a client from the connection pool.
    def check_out
      setup unless @setup_complete

      adapter = ActiveRecord::Base.connection_pool.checkout
      raw_conn = adapter.raw_connection

      @map_mutex.synchronize do
        @connection_map[raw_conn.object_id] = adapter
      end

      raw_conn
    end

    # This method is called to check a client back in to the connection when no longer needed.
    def check_in(client)
      return if client.nil? || !@setup_complete

      adapter = @map_mutex.synchronize do
        @connection_map.delete(client.object_id)
      end

      if adapter
        ActiveRecord::Base.connection_pool.checkin(adapter)
      else
        MysqlFramework.logger.warn { "[#{self.class}] - Unable to find adapter for raw connection during check_in" }
      end
    end

    # This method is called to use a client from the connection pool.
    def with_client(provided = nil)
      if provided
        yield provided
      else
        setup unless @setup_complete
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          yield connection.raw_connection
        end
      end
    end

    # This method is called to execute a prepared statement
    #
    # @note Ensure we free any result and close each statement, otherwise we
    # can run into a 'Commands out of sync' error if multiple threads are
    # running different queries at the same time.
    def execute(query, provided_client = nil)
      with_client(provided_client) do |client|
        statement = client.prepare(query.sql)
        result = statement.execute(*query.params)
        result&.to_a
      ensure
        result&.free
        statement&.close
      end
    end

    # This method is called to execute a query
    def query(query_string, provided_client = nil)
      with_client(provided_client) { |client| client.query(query_string) }
    end

    # This method is called to execute a query which will return multiple result sets in an array
    def query_multiple_results(query_string, provided_client = nil)
      results = with_client(provided_client) do |client|
        result = []
        result << client.query(query_string)
        result << client.store_result while client.next_result
        result.compact
      end

      results.map(&:to_a)
    end

    # This method is called to use a client within a transaction
    def transaction
      raise ArgumentError, 'No block was given' unless block_given?

      with_client do |client|
        begin
          client.query('BEGIN')
          yield client
          client.query('COMMIT')
        rescue StandardError => e
          client.query('ROLLBACK')
          raise e
        end
      end
    end

    private

    def default_options
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
    end

    def active_record_config
      {
        adapter: 'mysql2',
        host: @options[:host],
        port: @options[:port],
        database: @options[:database],
        username: @options[:username],
        password: @options[:password],
        reconnect: @options[:reconnect],
        read_timeout: @options[:read_timeout],
        write_timeout: @options[:write_timeout],
        pool: max_pool_size,
        checkout_timeout: pool_timeout
      }
    end

    def max_pool_size
      @max_pool_size ||= Integer(ENV.fetch('MYSQL_MAX_POOL_SIZE', 5))
    end

    def pool_timeout
      @pool_timeout ||= Integer(ENV.fetch('MYSQL_POOL_TIMEOUT', 5))
    end
  end
end
