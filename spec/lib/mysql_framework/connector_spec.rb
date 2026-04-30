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
  let(:client) { double(close: true, ping: true, closed?: false, abandon_results!: nil) }
  let(:gems) { MysqlFramework::SqlTable.new('gems') }
  let(:existing_client) { Mysql2::Client.new(default_options) }
  let(:connection_pooling_enabled) { 'true' }

  subject { described_class.new }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('MYSQL_CONNECTION_POOL_ENABLED', 'true')
      .and_return(connection_pooling_enabled)

    subject.setup
  end

  describe '#initialize' do
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

    it 'sets default query options on the Mysql2 client' do
      subject

      expect(Mysql2::Client.default_query_options[:symbolize_keys]).to eq(true)
      expect(Mysql2::Client.default_query_options[:cast_booleans]).to eq(true)
    end
  end

  describe '#setup' do
    context 'when connection pooling is enabled' do
      it 'creates a connection pool with expected stats' do
        subject.setup

        expect(subject.connection_pool).to be_a(MysqlFramework::MysqlConnectionPool)
        expect(subject.connection_pool.pool_stats[:size]).to eq(max_pool_size)
        expect(subject.connection_pool.pool_stats[:available]).to be >= 0
        expect(subject.connection_pool.pool_stats[:idle]).to be >= 0
      end
    end

    context 'when connection pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it "doesn't create a connection pool" do
        subject.setup

        expect(subject.connection_pool).to be_nil
      end
    end
  end

  describe '#dispose' do
    context 'when connection pooling is enabled' do
      it 'disposes of the pool and clears connector reference' do
        pool = instance_double(MysqlFramework::MysqlConnectionPool)
        allow(pool).to receive(:dispose)
        subject.instance_variable_set(:@connection_pool, pool)

        expect(pool).to receive(:dispose)
        subject.dispose

        expect(subject.connection_pool).to be_nil
      end
    end

    context 'when connection pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it 'does not perform more actions' do
        expect { subject.dispose }.not_to raise_error
        expect(subject.connection_pool).to be_nil
      end
    end
  end

  describe '#check_out' do
    context 'when connection pooling is enabled' do
      it 'checks out pooled connection' do
        pool = instance_double(MysqlFramework::MysqlConnectionPool)
        client = instance_double(Mysql2::Client)
        allow(pool).to receive(:check_out).and_return(client)
        subject.instance_variable_set(:@connection_pool, pool)

        expect(pool).to receive(:check_out)
        expect(subject.check_out).to eq(client)
      end
    end

    context 'when pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it 'returns a new client directly' do
        new_client = instance_double(Mysql2::Client)
        allow(Mysql2::Client).to receive(:new).and_return(new_client)

        expect(subject.check_out).to eq(new_client)
      end
    end
  end

  describe '#check_in' do
    context 'when connection pooling is enabled' do
      it 'checks in a pooled connection' do
        pool = instance_double(MysqlFramework::MysqlConnectionPool)
        allow(pool).to receive(:check_in)
        subject.instance_variable_set(:@connection_pool, pool)

        expect(pool).to receive(:check_in)
        subject.check_in(client)
      end
    end

    context 'when pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it 'closes the provided client' do
        new_client = instance_double(Mysql2::Client, close: nil)

        expect(new_client).to receive(:close)
        subject.check_in(new_client)
      end
    end
  end

  describe '#with_client' do
    context 'when a provided_client is given' do
      it 'yields the provided client directly' do
        expect { |b| subject.with_client(client, &b) }.to yield_with_args(client)
      end

      it 'does not interact with the connection pool' do
        expect(subject).not_to receive(:with_new_client)
        expect(subject.connection_pool).not_to receive(:with_client) if subject.connection_pool

        subject.with_client(client) { |_c| nil }
      end

      it 'returns the block result' do
        result = subject.with_client(client) { |_c| :expected }
        expect(result).to eq(:expected)
      end
    end

    context 'when no provided_client is given' do
      context 'when connection pooling is disabled' do
        let(:connection_pooling_enabled) { 'false' }

        it 'delegates to with_new_client' do
          expect(subject).to receive(:with_new_client).and_yield(client)

          expect { |b| subject.with_client(&b) }.to yield_with_args(client)
        end

        it 'returns the block result' do
          allow(subject).to receive(:with_new_client).and_yield(client)

          result = subject.with_client { |_c| :expected }
          expect(result).to eq(:expected)
        end
      end

      context 'when connection pooling is enabled' do
        it 'delegates to the connection pool' do
          pool = instance_double(MysqlFramework::MysqlConnectionPool)
          subject.instance_variable_set(:@connection_pool, pool)

          expect(pool).to receive(:with_client).with(discard_current_pool_connection: false).and_yield(client)
          expect { |b| subject.with_client(&b) }.to yield_with_args(client)
        end

        it 'passes discard_current_pool_connection: true to the pool when requested' do
          pool = instance_double(MysqlFramework::MysqlConnectionPool)
          subject.instance_variable_set(:@connection_pool, pool)

          expect(pool).to receive(:with_client).with(discard_current_pool_connection: true).and_yield(client)
          subject.with_client(discard_current_pool_connection: true) { |_c| nil }
        end

        it 'returns the block result' do
          pool = instance_double(MysqlFramework::MysqlConnectionPool)
          subject.instance_variable_set(:@connection_pool, pool)
          allow(pool).to receive(:with_client).and_yield(client)

          result = subject.with_client { |_c| :expected }
          expect(result).to eq(:expected)
        end
      end
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

    it 'does not check out a new client when one is provided' do
      expect(subject).not_to receive(:check_out)

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
        allow(mock_client).to receive(:abandon_results!)
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
    before(:each) { allow(subject).to receive(:with_client).and_yield(client) }

    it 'retrieves a client and calls query' do
      expect(client).to receive(:query).with('SELECT 1')

      subject.query('SELECT 1')
    end

    it 'does not check out a new client when one is provided' do
      expect(subject).to receive(:with_client).with(existing_client).and_yield(existing_client)
      expect(existing_client).to receive(:query).with('SELECT 1')

      subject.query('SELECT 1', existing_client)
    end
  end

  describe '#query_multiple_results' do
    it 'uses with_client with discard_current_pool_connection enabled' do
      query_call = instance_double(Mysql2::Result, to_a: [], free: true)
      allow(client).to receive(:query).and_return(query_call)
      allow(client).to receive(:more_results?).and_return(false)
      allow(client).to receive(:abandon_results!)

      expect(subject).to receive(:with_client)
        .with(nil, discard_current_pool_connection: true)
        .and_yield(client)

      subject.query_multiple_results('call test_procedure')
    end

    it 'returns the results from the stored procedure' do
      query = 'call test_procedure'
      result = subject.query_multiple_results(query)

      expect(result).to be_a(Array)
      expect(result.length).to eq(2)
      expect(result[0].length).to eq(0)
      expect(result[1].length).to eq(4)
    end

    it 'does not check out a new client when one is provided' do
      expect(subject).not_to receive(:check_out)

      query = 'call test_procedure'
      result = subject.query_multiple_results(query, existing_client)

      expect(result).to be_a(Array)
      expect(result.length).to eq(2)
      expect(result[0].length).to eq(0)
      expect(result[1].length).to eq(4)
    end
  end

  describe '#transaction' do
    before(:each) { allow(subject).to receive(:with_client).and_yield(client) }

    it 'wraps the client call with BEGIN and COMMIT statements' do
      expect(client).to receive(:query).with('BEGIN')
      expect(client).to receive(:query).with('SELECT 1')
      expect(client).to receive(:query).with('COMMIT')

      subject.transaction { subject.query('SELECT 1') }
    end

    context 'when an exception occurs' do
      it 'triggers a ROLLBACK' do
        expect(client).to receive(:query).with('BEGIN')
        expect(client).to receive(:query).with('ROLLBACK')

        begin
          subject.transaction { raise }
        rescue StandardError => e
          e.message
        end
      end
    end
  end
end
