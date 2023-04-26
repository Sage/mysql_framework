# frozen_string_literal: true

module MysqlFramework
  class Connector
    def initialize(options = {})
      @options = default_options.merge(options)
      @mutex = Mutex.new

      Mysql2::Client.default_query_options.merge!(symbolize_keys: true, cast_booleans: true)
    end

    # This method is called to setup a pool of MySQL connections.
    def setup
      return unless connection_pool_enabled?

      @connection_pool = ::Queue.new

      start_pool_size.times { @connection_pool.push(new_client) }

      @created_connections = start_pool_size
    end

    # This method is called to close all MySQL connections in the pool and dispose of the pool itself.
    def dispose
      return if @connection_pool.nil?

      until @connection_pool.empty?
        conn = @connection_pool.pop(true)
        conn&.close
      end

      @connection_pool = nil
    end

    # This method is called to get the idle connection queue for this connector.
    def connections
      @connection_pool
    end

    # This method is called to fetch a client from the connection pool.
    def check_out
      @mutex.synchronize do
        begin
          return new_client unless connection_pool_enabled?

          client = @connection_pool.pop(true)

          client.ping if @options[:reconnect]

          client
        rescue ThreadError
          if @created_connections < max_pool_size
            client = new_client
            @created_connections += 1
            return client
          end

          MysqlFramework.logger.error { "[#{self.class}] - Database connection pool depleted." }

          raise 'Database connection pool depleted.'
        end
      end
    end

    # This method is called to check a client back in to the connection when no longer needed.
    def check_in(client)
      @mutex.synchronize do
        return client&.close unless connection_pool_enabled?

        client = new_client if client&.closed?
        @connection_pool.push(client)
      end
    end

    # This method is called to use a client from the connection pool.
    def with_client(provided = nil)
      client = provided || check_out
      yield client
    ensure
      MysqlFramework.logger.error { "[#{self.class}] - Checking in nil client \n#{caller}" } unless client 
      check_in(client) unless provided
    end

    # This method is called to execute a prepared statement
    #
    # @note Ensure we free any result and close each statement, otherwise we
    # can run into a 'Commands out of sync' error if multiple threads are
    # running different queries at the same time.
    def execute(query, provided_client = nil)
      with_client(provided_client) do |client|
        begin
          statement = client.prepare(query.sql)
          result = statement.execute(*query.params)
          result&.to_a
        ensure
          result&.free
          statement&.close
        end
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

    def new_client
      Mysql2::Client.new(@options)
    end

    def connection_pool_enabled?
      @connection_pool_enabled ||= ENV.fetch('MYSQL_CONNECTION_POOL_ENABLED', 'true').casecmp?('true')
    end

    def start_pool_size
      @start_pool_size ||= Integer(ENV.fetch('MYSQL_START_POOL_SIZE', 1))
    end

    def max_pool_size
      @max_pool_size ||= Integer(ENV.fetch('MYSQL_MAX_POOL_SIZE', 5))
    end
  end
end
