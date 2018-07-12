# frozen_string_literal: true

module MysqlFramework
  class Connector
    def initialize(options = {})
      @connection_pool = ::Queue.new

      @options = default_options.merge(options)

      Mysql2::Client.default_query_options.merge!(symbolize_keys: true, cast_booleans: true)
    end

    # This method is called to fetch a client from the connection pool or create a new client if no idle clients
    # are available.
    def check_out
      @connection_pool.pop(true)
    rescue StandardError
      Mysql2::Client.new(@options)
    end

    # This method is called to check a client back in to the connection when no longer needed.
    def check_in(client)
      @connection_pool.push(client)
    end

    # This method is called to use a client from the connection pool.
    def with_client(provided = nil)
      client = provided || check_out
      yield client
    ensure
      check_in(client) unless provided
    end

    # This method is called to execute a prepared statement
    def execute(query)
      with_client do |client|
        statement = client.prepare(query.sql)
        statement.execute(*query.params)
      end
    end

    # This method is called to execute a query
    def query(query_string)
      with_client { |client| client.query(query_string) }
    end

    # This method is called to execute a query which will return multiple result sets in an array
    def query_multiple_results(query_string)
      with_client do |client|
        result = []
        result << client.query(query_string).to_a
        result << client.store_result&.to_a while client.next_result
        result.compact
      end
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

    def default_options
      {
        host:      ENV.fetch('MYSQL_HOST'),
        port:      ENV.fetch('MYSQL_PORT'),
        database:  ENV.fetch('MYSQL_DATABASE'),
        username:  ENV.fetch('MYSQL_USERNAME'),
        password:  ENV.fetch('MYSQL_PASSWORD'),
        reconnect: true
      }
    end
  end
end
