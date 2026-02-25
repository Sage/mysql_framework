# frozen_string_literal: true

describe MysqlFramework::Connector do
  let(:max_pool_size) { Integer(ENV.fetch('MYSQL_MAX_POOL_SIZE')) }
  let(:default_options) do
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
  let(:options) do
    {
      host: ENV.fetch('MYSQL_HOST'),
      port: ENV.fetch('MYSQL_PORT'),
      database: "#{ENV.fetch('MYSQL_DATABASE')}_2",
      username: ENV.fetch('MYSQL_USERNAME'),
      password: ENV.fetch('MYSQL_PASSWORD'),
      reconnect: false
    }
  end
  let(:client) { double(close: true, ping: true, closed?: false) }
  let(:gems) { MysqlFramework::SqlTable.new('gems') }
  let(:existing_client) { subject.check_out }

  subject { described_class.new }

  before(:each) { subject.setup }
  after(:each) { subject.dispose }

  describe '#initialize' do
    it 'initializes the connection map as nil' do
      connector = described_class.new
      expect(connector.instance_variable_get(:@connection_map)).to be_nil
    end

    it 'initializes the map mutex' do
      connector = described_class.new
      expect(connector.instance_variable_get(:@map_mutex)).to be_a(Mutex)
    end

    context 'when options are not provided' do
      it 'returns the default options' do
        expect(subject.instance_variable_get(:@options)).to eq(default_options)
      end
    end

    context 'when options are provided' do
      subject { described_class.new(options) }

      it 'allows the default options to be overridden' do
        expected = {
          host: ENV.fetch('MYSQL_HOST'),
          port: ENV.fetch('MYSQL_PORT'),
          database: "#{ENV.fetch('MYSQL_DATABASE')}_2",
          username: ENV.fetch('MYSQL_USERNAME'),
          password: ENV.fetch('MYSQL_PASSWORD'),
          reconnect: false,
          read_timeout: Integer(ENV.fetch('MYSQL_READ_TIMEOUT', 30)),
          write_timeout: Integer(ENV.fetch('MYSQL_WRITE_TIMEOUT', 10))
        }

        expect(subject.instance_variable_get(:@options)).to eq(expected)
      end
    end
  end

  describe '#setup' do
    it 'creates an ActiveRecord connection pool' do
      subject.setup

      expect(subject.connections).to be_a(ActiveRecord::ConnectionAdapters::ConnectionPool)
    end

    it 'initializes the connection map as an empty hash' do
      connector = described_class.new
      expect(connector.instance_variable_get(:@connection_map)).to be_nil

      connector.setup

      expect(connector.instance_variable_get(:@connection_map)).to eq({})
    end

    it 'does not create a new pool if one already exists' do
      subject.setup
      pool = subject.connections

      subject.setup

      expect(subject.connections).to eq(pool)
    end

    it 'is thread-safe when called concurrently' do
      connector = described_class.new

      threads = 10.times.map do
        Thread.new { connector.setup }
      end

      threads.each(&:join)

      # Should only have one connection pool created
      expect(connector.connections).to be_a(ActiveRecord::ConnectionAdapters::ConnectionPool)
      expect(connector.instance_variable_get(:@connection_map)).to eq({})

      connector.dispose
    end
  end

  describe '#dispose' do
    it 'disconnects all connections and sets pool to nil' do
      subject.setup
      expect(subject.connections).to receive(:disconnect!)

      subject.dispose

      expect(subject.connections).to be_nil
    end

    it 'does nothing if pool is already nil' do
      subject.dispose
      expect { subject.dispose }.not_to raise_error
    end

    it 'clears the connection mapping' do
      client = subject.check_out
      connection_map = subject.instance_variable_get(:@connection_map)

      expect(connection_map.size).to eq(1)

      subject.check_in(client)
      subject.dispose

      expect(connection_map).to be_empty
    end

    it 'clears the mapping even with outstanding checkouts' do
      client1 = subject.check_out
      client2 = subject.check_out
      connection_map = subject.instance_variable_get(:@connection_map)

      expect(connection_map.size).to eq(2)

      subject.dispose

      expect(connection_map).to be_empty
    end
  end

  describe '#check_out' do
    it 'returns a raw Mysql2::Client from the pool' do
      client = subject.check_out
      expect(client).to be_a(Mysql2::Client)
    end

    it 'sets up the pool if not already setup' do
      connector = described_class.new
      expect(connector.connections).to be_nil

      client = connector.check_out

      expect(connector.connections).not_to be_nil
      expect(client).to be_a(Mysql2::Client)

      connector.dispose
    end

    it 'creates a mapping entry for the checked out connection' do
      connection_map = subject.instance_variable_get(:@connection_map)
      expect(connection_map).to be_empty

      client = subject.check_out

      expect(connection_map.size).to eq(1)
      expect(connection_map[client.object_id]).to be_a(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
    end

    it 'creates separate mapping entries for multiple checkouts' do
      connection_map = subject.instance_variable_get(:@connection_map)

      client1 = subject.check_out
      client2 = subject.check_out

      expect(connection_map.size).to eq(2)
      expect(connection_map[client1.object_id]).not_to be_nil
      expect(connection_map[client2.object_id]).not_to be_nil
      expect(connection_map[client1.object_id]).not_to eq(connection_map[client2.object_id])
    end
  end

  describe '#check_in' do
    it 'returns the client to the connection pool' do
      client = subject.check_out
      expect { subject.check_in(client) }.not_to raise_error
    end

    it 'does nothing when client is nil' do
      expect { subject.check_in(nil) }.not_to raise_error
    end

    it 'does nothing when pool is nil' do
      subject.dispose
      expect { subject.check_in(client) }.not_to raise_error
    end

    it 'removes the mapping entry when checking in' do
      connection_map = subject.instance_variable_get(:@connection_map)
      client = subject.check_out

      expect(connection_map.size).to eq(1)
      expect(connection_map[client.object_id]).not_to be_nil

      subject.check_in(client)

      expect(connection_map.size).to eq(0)
      expect(connection_map[client.object_id]).to be_nil
    end

    it 'actually returns the connection to the pool' do
      client = subject.check_out
      subject.check_in(client)

      expect { subject.check_out }.not_to raise_error
    end

    it 'logs a warning when adapter is not found in mapping' do
      fake_client = double('Mysql2::Client', object_id: 999999)

      expect(MysqlFramework.logger).to receive(:warn) do |&block|
        expect(block.call).to match(/Unable to find adapter for raw connection/)
      end

      subject.check_in(fake_client)
    end

    it 'handles concurrent check_in operations safely' do
      threads = 3.times.map do
        Thread.new do
          client = subject.check_out
          subject.check_in(client)
        end
      end

      threads.each(&:join)

      connection_map = subject.instance_variable_get(:@connection_map)
      expect(connection_map).to be_empty
    end
  end

  describe '#with_client' do
    it 'uses the client that is provided, if passed one' do
      expect { |b| subject.with_client(client, &b) }.to yield_with_args(client)
    end

    it 'obtains a client from the pool and yields it' do
      subject.with_client do |client|
        expect(client).to be_a(Mysql2::Client)
      end
    end

    it 'automatically returns the client to the pool after the block' do
      subject.with_client do |client|
        expect(client).to be_a(Mysql2::Client)
      end

      # Should be able to check out again without issues
      subject.with_client do |client|
        expect(client).to be_a(Mysql2::Client)
      end
    end

    it 'does not add entries to the connection map' do
      connection_map = subject.instance_variable_get(:@connection_map)
      expect(connection_map).to be_empty

      subject.with_client do |client|
        expect(client).to be_a(Mysql2::Client)
        # Map should still be empty since with_client manages its own checkout/checkin
        expect(connection_map).to be_empty
      end

      # Map should remain empty after the block completes
      expect(connection_map).to be_empty
    end
  end

  describe '#execute' do
    let(:insert_query) do
      MysqlFramework::SqlQuery.new.insert(gems)
        .into(gems[:id], gems[:name], gems[:author], gems[:created_at], gems[:updated_at])
        .values(SecureRandom.uuid, 'mysql_framework', 'sage', Time.now, Time.now)
    end

    it 'executes the query with parameters' do
      guid = insert_query.params[0]
      subject.execute(insert_query)

      results = subject.query("SELECT * FROM `gems` WHERE id = '#{guid}';").to_a
      expect(results.length).to eq(1)
      expect(results[0][:id]).to eq(guid)
    end

    it 'uses the provided client when one is given' do
      guid = insert_query.params[0]
      subject.execute(insert_query, existing_client)

      results = subject.query("SELECT * FROM `gems` WHERE id = '#{guid}';", existing_client).to_a
      expect(results.length).to eq(1)
      expect(results[0][:id]).to eq(guid)
    end

    context 'when cleaning up resources' do
      let(:mock_client) { double('client') }
      let(:mock_statement) { double('statement') }
      let(:mock_result) { double('result') }
      let(:select_query) { MysqlFramework::SqlQuery.new.select('*').from('demo') }

      before do
        allow(mock_result).to receive(:to_a)
        allow(mock_result).to receive(:free)

        allow(mock_statement).to receive(:close)
        allow(mock_statement).to receive(:execute).and_return(mock_result)

        allow(mock_client).to receive(:prepare).and_return(mock_statement)
      end

      it 'frees the result' do
        expect(mock_result).to receive(:free)

        subject.execute(select_query, mock_client)
      end

      it 'closes the statement' do
        expect(mock_statement).to receive(:close)

        subject.execute(select_query, mock_client)
      end
    end

    it 'does not raise a commands out of sync error' do
      threads = []
      threads << Thread.new do
        350.times do
          update_query = MysqlFramework::SqlQuery.new.update('gems')
                                                 .set(updated_at: Time.now)
          expect { subject.execute(update_query) }.not_to raise_error
        end
      end

      threads << Thread.new do
        350.times do
          select_query = MysqlFramework::SqlQuery.new.select('*').from('demo')
          expect { subject.execute(select_query) }.not_to raise_error
        end
      end

      threads << Thread.new do
        350.times do
          select_query = MysqlFramework::SqlQuery.new.select('*').from('test')
          expect { subject.execute(select_query) }.not_to raise_error
        end
      end

      threads.each(&:join)
    end
  end

  describe '#query' do
    it 'executes a query and returns results' do
      result = subject.query('SELECT 1 as num')
      expect(result.to_a).to eq([{ num: 1 }])
    end

    it 'uses the provided client when one is given' do
      result = subject.query('SELECT 1 as num', existing_client)
      expect(result.to_a).to eq([{ num: 1 }])
    end

    context 'query options' do
      it 'returns results as hashes with symbol keys' do
        result = subject.query('SELECT 1 as column_name')
        row = result.first

        expect(row).to be_a(Hash)
        expect(row.keys.first).to be_a(Symbol)
        expect(row).to eq({ column_name: 1 })
      end

      it 'does not return results as arrays' do
        result = subject.query('SELECT 1 as num, 2 as other')
        row = result.first

        expect(row).not_to be_a(Array)
        expect(row[:num]).to eq(1)
        expect(row[:other]).to eq(2)
      end
    end
  end

  describe '#query_multiple_results' do
    it 'returns the results from the stored procedure' do
      query = 'call test_procedure'
      result = subject.query_multiple_results(query)

      expect(result).to be_a(Array)
      expect(result.length).to eq(2)
      expect(result[0].length).to eq(0)
      expect(result[1].length).to eq(4)
    end

    it 'uses the provided client when one is given' do
      query = 'call test_procedure'
      result = subject.query_multiple_results(query, existing_client)

      expect(result).to be_a(Array)
      expect(result.length).to eq(2)
      expect(result[0].length).to eq(0)
      expect(result[1].length).to eq(4)
    end
  end

  describe '#transaction' do
    it 'commits the transaction on success' do
      guid = SecureRandom.uuid

      subject.transaction do |client|
        client.query("INSERT INTO `gems` (`id`, `name`) VALUES ('#{guid}', 'test_gem')")
      end

      results = subject.query("SELECT * FROM `gems` WHERE id = '#{guid}';").to_a
      expect(results.length).to eq(1)
    end

    it 'rolls back the transaction on error' do
      guid = SecureRandom.uuid

      expect do
        subject.transaction do |client|
          client.query("INSERT INTO `gems` (`id`, `name`) VALUES ('#{guid}', 'test_gem')")
          raise 'test error'
        end
      end.to raise_error(RuntimeError, 'test error')

      results = subject.query("SELECT * FROM `gems` WHERE id = '#{guid}';").to_a
      expect(results.length).to eq(0)
    end

    it 'raises ArgumentError when no block is given' do
      expect { subject.transaction }.to raise_error(ArgumentError, 'No block was given')
    end
  end

  describe 'connection pool behavior' do
    it 'reuses connections from the pool' do
      client1 = nil
      client2 = nil

      subject.with_client { |c| client1 = c }
      subject.with_client { |c| client2 = c }

      # ActiveRecord should reuse the same connection for the same thread
      expect(client1).to eq(client2)
    end

    it 'handles concurrent access' do
      results = Queue.new
      threads = 10.times.map do
        Thread.new do
          subject.with_client do |client|
            # Use array index since raw client doesn't have symbolize_keys set
            result = client.query('SELECT CONNECTION_ID() as id').first[0]
            results << result
          end
        end
      end

      threads.each(&:join)

      # All queries should have completed successfully
      expect(results.size).to eq(10)
    end
  end

  describe 'connection mapping thread safety' do
    it 'handles concurrent check_out operations safely' do
      threads = 5.times.map do
        Thread.new do
          client = subject.check_out
          sleep(0.01)
          subject.check_in(client)
        end
      end

      threads.each(&:join)

      connection_map = subject.instance_variable_get(:@connection_map)
      expect(connection_map).to be_empty
    end

    it 'maintains correct mappings under concurrent access' do
      connection_map = subject.instance_variable_get(:@connection_map)

      # Each thread checks out and checks in its own connection
      threads = 5.times.map do
        Thread.new do
          client = subject.check_out
          # Verify mapping exists for this thread's connection
          mapping_exists = false
          subject.instance_variable_get(:@map_mutex).synchronize do
            mapping_exists = connection_map[client.object_id].is_a?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
          end
          expect(mapping_exists).to be true

          subject.check_in(client)
        end
      end

      threads.each(&:join)

      expect(connection_map).to be_empty
    end

    it 'does not lose mappings during concurrent operations' do
      iterations = 20
      errors = []

      threads = 3.times.map do
        Thread.new do
          iterations.times do
            begin
              client = subject.check_out
              sleep(0.01)
              subject.check_in(client)
            rescue StandardError => e
              errors << e
            end
          end
        end
      end

      threads.each(&:join)

      expect(errors).to be_empty
      connection_map = subject.instance_variable_get(:@connection_map)
      expect(connection_map).to be_empty
    end
  end
end
