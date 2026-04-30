# frozen_string_literal: true

require 'connection_pool'

module MysqlFramework
  class MysqlConnectionPool
    class ConnectionSanitizationError < StandardError; end

    CLEAN_IDLE_CONNECTIONS_THREAD_NAME = 'clean-idle-connections'

    attr_reader :connections

    # Initializes a connection pool instance with MySQL client options.
    #
    # @param options [Hash] MySQL client options passed to each pooled connection
    # @return [void]
    def initialize(options)
      @options = options
      @setup_mutex = Mutex.new
    end

    # Sets up the MySQL connection pool. Idempotent — safe to call more than once.
    #
    # @return [ConnectionPool] configured pool
    def setup
      @setup_mutex.synchronize do
        return if connections

        @connections = ConnectionPool.new(size: max_pool_size, timeout: pool_timeout) do
          Mysql2::Client.new(@options)
        end

        start_clean_idle_connections_thread
      end
    end

    # Disposes of the connection pool and closes pooled connections.
    #
    # @return [void]
    def dispose
      @setup_mutex.synchronize do
        dispose_clean_idle_connections_thread
        connections&.shutdown(&:close)
        @connections = nil
      end
    end

    # Returns key connection-pool metrics for monitoring.
    #
    # @return [Hash{Symbol => Integer}] pool size and availability metrics
    def pool_stats
      return { size: 0, available: 0, idle: 0 } if connections.nil?

      {
        size: connections.size,
        available: connections.available,
        idle: connections.idle
      }
    end

    # Checks out a MySQL client, sanitizing it before use.
    #
    # @return [Mysql2::Client] checked-out client
    # @raise [ConnectionSanitizationError] when sanitization repeatedly fails
    # @raise [Mysql2::Error] when checkout or sanitization fails due to MySQL errors
    def check_out
      sanitization_retries = 0
      begin
        conn = connections.checkout
        sanitize_connection!(conn)
        conn
      rescue ConnectionSanitizationError
        discard_current_connection!
        sanitization_retries += 1
        retry if sanitization_retries <= 1
        raise
      rescue Mysql2::Error
        discard_current_connection!
        raise
      end
    end

    # Returns a MySQL client back to the pool or closes it when pooling is disabled.
    #
    # @param client [Mysql2::Client, nil] client to return or close
    # @return [void]
    def check_in(client)
      return if client.nil?

      discard_current_connection! if client.closed?
      connections.checkin
    end

    # Yields a MySQL client from the pool, or yields the provided client directly.
    #
    # @param provided_client [Mysql2::Client, nil] existing client to yield without pool checkout
    # @param discard_current_pool_connection [Boolean] whether to discard the pooled connection after use
    # @yield [client] block that performs work with a MySQL client
    # @yieldparam client [Mysql2::Client]
    # @return [Object] block result
    # @raise [Mysql2::Error] re-raises MySQL errors from the block
    def with_client(discard_current_pool_connection: false)
      sanitization_retries = 0

      begin
        connections.with do |conn|
          sanitize_connection!(conn)
          yield conn
        rescue ConnectionSanitizationError, Mysql2::Error
          discard_current_connection!
          raise
        ensure
          discard_current_connection! if discard_current_pool_connection
        end
      rescue ConnectionSanitizationError
        sanitization_retries += 1
        retry if sanitization_retries <= 1
        raise
      end
    end

    private

    def start_clean_idle_connections_thread
      @idle_connections_thread = Thread.new do
        Thread.current.name = CLEAN_IDLE_CONNECTIONS_THREAD_NAME
        loop do
          sleep idle_reap_loop_time
          break unless Thread.current == @idle_connections_thread

          connections&.reap(idle_seconds: idle_timeout, &:close)
        end
      end

      @idle_connections_thread.abort_on_exception = false
      @idle_connections_thread
    end

    def dispose_clean_idle_connections_thread
      @idle_connections_thread&.join(5)
      @idle_connections_thread&.kill
      @idle_connections_thread = nil
    end

    def sanitize_connection!(conn)
      conn.ping
      conn.abandon_results!
      conn.query('ROLLBACK')
    rescue Mysql2::Error => e
      raise ConnectionSanitizationError, "Connection sanitization failed: #{e.message}"
    end

    def discard_current_connection!
      connections&.discard_current_connection(&:close)
    rescue StandardError
      nil
    end

    def max_pool_size
      @max_pool_size ||= Integer(ENV.fetch('MYSQL_MAX_POOL_SIZE', 5))
    end

    def pool_timeout
      @pool_timeout ||= Integer(ENV.fetch('MYSQL_POOL_TIMEOUT', 5))
    end

    def idle_timeout
      @idle_timeout ||= Integer(ENV.fetch('MYSQL_POOL_IDLE_TIMEOUT', 300))
    end

    def idle_reap_loop_time
      @idle_reap_loop_time ||= Integer(ENV.fetch('MYSQL_POOL_IDLE_REAP_TIME', 60))
    end
  end
end
