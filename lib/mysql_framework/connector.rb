# frozen_string_literal: true

require 'connection_pool'
require_relative 'mysql_connection_pool'

module MysqlFramework
  class Connector
    attr_reader :connection_pool

    # Initializes a connector instance with MySQL client options.
    #
    # @param options [Hash] custom MySQL client options that override defaults
    # @return [void]
    def initialize(options = {})
      @options = default_options.merge(options)
      Mysql2::Client.default_query_options.merge!(symbolize_keys: true, cast_booleans: true)
    end

    # Sets up the MySQL connection pool when pooling is enabled.
    #
    # @return [ConnectionPool, nil] configured pool, or nil when pooling is disabled
    def setup
      return unless connection_pool_enabled?

      @connection_pool = MysqlFramework::MysqlConnectionPool.new(@options)
      @connection_pool.setup
    end

    # Disposes of the connection pool and closes pooled connections.
    #
    # @return [void]
    def dispose
      return unless connection_pool_enabled?

      @connection_pool&.dispose
      @connection_pool = nil
    end

    # Checks out a MySQL client, sanitizing it before use.
    #
    # @return [Mysql2::Client] checked-out client
    # @raise [ConnectionSanitizationError] when sanitization repeatedly fails
    # @raise [Mysql2::Error] when checkout or sanitization fails due to MySQL errors
    def check_out
      return new_client unless connection_pool_enabled?

      @connection_pool.check_out
    end

    # Returns a MySQL client back to the pool or closes it when pooling is disabled.
    #
    # @param client [Mysql2::Client, nil] client to return or close
    # @return [void]
    def check_in(client)
      return client&.close unless connection_pool_enabled?

      @connection_pool.check_in(client)
    end

    # Yields a MySQL client from the pool, or yields the provided client directly.
    #
    # @param provided_client [Mysql2::Client, nil] existing client to yield without pool checkout
    # @param discard_current_pool_connection [Boolean] whether to discard the pooled connection after use
    # @yield [client] block that performs work with a MySQL client
    # @yieldparam client [Mysql2::Client]
    # @return [Object] block result
    # @raise [Mysql2::Error] re-raises MySQL errors from the block
    def with_client(provided_client = nil, discard_current_pool_connection: false)
      return yield provided_client if provided_client
      return with_new_client { |c| yield c } unless connection_pool_enabled?

      @connection_pool.with_client(discard_current_pool_connection:) { |c| yield c }
    end

    # Executes a prepared statement.
    #
    # @param query [Object] query object responding to +sql+ and +params+
    # @param provided_client [Mysql2::Client, nil] optional existing client
    # @return [Array<Hash>, nil] query result rows
    # @raise [Mysql2::Error] when statement preparation or execution fails
    #
    # NOTE:
    # We must always free the result and close the prepared statement.
    # Otherwise MySQL may raise "Commands out of sync" when the same
    # connection is reused (e.g. via connection pooling).
    #
    # The connection itself must NOT be closed here because it is
    # managed by the connection pool.
    def execute(query, provided_client = nil)
      with_client(provided_client) do |client|
        statement = nil
        result = nil

        begin
          statement = client.prepare(query.sql)
          result = statement.execute(
            *query.params, symbolize_keys: true, cast_booleans: true
          )
          final = result&.to_a
          final
        ensure
          client&.abandon_results!
          result&.free
          statement&.close
        end
      end
    end

    # Executes a SQL query.
    #
    # @param query_string [String] SQL query to execute
    # @param provided_client [Mysql2::Client, nil] optional existing client
    # @return [Mysql2::Result] raw MySQL result
    # @raise [Mysql2::Error] when query execution fails
    def query(query_string, provided_client = nil)
      with_client(provided_client) { |conn| conn.query(query_string) }
    end

    # Executes a multi-statement SQL query and collects all result sets.
    #
    # @param query_string [String] multi-statement SQL query
    # @param provided_client [Mysql2::Client, nil] optional existing client
    # @return [Array<Array<Hash>>] list of result sets
    # @raise [Mysql2::Error] when query execution or result fetching fails
    def query_multiple_results(query_string, provided_client = nil)
      results = nil

      # Multiple statement query is buggy and client cannot be reused after calling next_result/store_result
      # Client's state gets corrupted and leaks into next queries. The reason is unknown.
      # As a result we do not return client back to the pool but instead close connection which is not optimal.
      with_client(provided_client, discard_current_pool_connection: true) do |client|
        raw_results = []
        query_call = client.query(query_string)
        raw_results << query_call&.to_a
        query_call&.free

        while client.more_results?
          client.next_result
          query_call = client.store_result
          raw_results << query_call&.to_a
          query_call&.free
        end

        results = raw_results.compact
        results
      ensure
        client&.abandon_results!
      end

      results
    end

    # Executes a block within a database transaction.
    #
    # @yield [client] block executed between BEGIN and COMMIT
    # @yieldparam client [Mysql2::Client]
    # @return [Object] block result
    # @raise [LocalJumpError] when no block is given
    # @raise [StandardError] re-raises any exception after rollback
    def transaction
      raise LocalJumpError, 'No block was given' unless block_given?

      with_client do |client|
        client.query('BEGIN')
        yield client
        client.query('COMMIT')
      rescue StandardError => e
        client.query('ROLLBACK')
        raise e
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

    def with_new_client
      client = new_client
      yield client
    ensure
      client&.close
    end

    def new_client
      Mysql2::Client.new(@options)
    end

    def connection_pool_enabled?
      return @connection_pool_enabled unless @connection_pool_enabled.nil?

      @connection_pool_enabled = ENV.fetch('MYSQL_CONNECTION_POOL_ENABLED', 'false').casecmp?('true')
    end
  end
end
