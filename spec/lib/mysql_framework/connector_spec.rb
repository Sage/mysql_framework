# frozen_string_literal: true

describe MysqlFramework::Connector do
  let(:start_pool_size) { Integer(ENV.fetch('MYSQL_START_POOL_SIZE')) }
  let(:max_pool_size) { Integer(ENV.fetch('MYSQL_MAX_POOL_SIZE')) }
  let(:default_options) do
    {
      host: ENV.fetch('MYSQL_HOST'),
      port: ENV.fetch('MYSQL_PORT'),
      database: ENV.fetch('MYSQL_DATABASE'),
      username: ENV.fetch('MYSQL_USERNAME'),
      password: ENV.fetch('MYSQL_PASSWORD'),
      reconnect: true,
      read_timeout: ENV.fetch('MYSQL_READ_TIMEOUT', 30),
      write_timeout: ENV.fetch('MYSQL_WRITE_TIMEOUT', 10)
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
  let(:existing_client) { Mysql2::Client.new(default_options) }
  let(:connection_pooling_enabled) { 'true' }

  subject { described_class.new }

  before(:each) do
    original_fetch = ENV.method(:fetch)

    allow(ENV).to receive(:fetch) do |var, default|
      if var == 'MYSQL_CONNECTION_POOL_ENABLED'
        connection_pooling_enabled
      else
        original_fetch.call(var, default)
      end
    end

    subject.setup
  end

  after(:each) { subject.dispose }

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
          read_timeout: ENV.fetch('MYSQL_READ_TIMEOUT', 30),
          write_timeout: ENV.fetch('MYSQL_WRITE_TIMEOUT', 10)
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
      it 'creates a connection pool with the specified number of conections' do
        subject.setup

        expect(subject.connections.length).to eq(start_pool_size)
      end
    end

    context 'when connection pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it "doesn't create a connection pool" do
        subject.setup

        expect(subject.connections).to be_nil
      end
    end
  end

  describe '#dispose' do
    before do
      subject.connections.clear
      subject.connections.push(client)
    end

    it 'closes the idle connections and disposes of the queue' do
      expect(client).to receive(:close)

      subject.dispose

      expect(subject.connections).to be_nil
    end
  end

  describe '#check_out' do
    context 'when connection pooling is enabled' do
      context 'when there are available connections' do
        before do
          subject.connections.clear
          subject.connections.push(client)
        end

        it 'returns a client instance from the pool' do
          expect(subject.check_out).to eq(client)
        end

        context 'and :reconnect is set to true' do
          let(:options) do
            {
              host: ENV.fetch('MYSQL_HOST'),
              port: ENV.fetch('MYSQL_PORT'),
              database: "#{ENV.fetch('MYSQL_DATABASE')}_2",
              username: ENV.fetch('MYSQL_USERNAME'),
              password: ENV.fetch('MYSQL_PASSWORD'),
              reconnect: true
            }
          end

          subject { described_class.new(options) }

          it 'pings the server to force a reconnect' do
            expect(client).to receive(:ping)

            subject.check_out
          end
        end

        context 'and :reconnect is set to false' do
          subject { described_class.new(options) }

          it 'pings the server to force a reconnect' do
            expect(client).not_to receive(:ping)

            subject.check_out
          end
        end
      end

      context 'when connection pooling is disabled' do
        let(:connection_pooling_enabled) { 'false' }

        it 'instantiates and returns a new connection directly' do
          expect(subject.connections).not_to receive(:pop)
          expect(Mysql2::Client).to receive(:new)

          subject.check_out
        end
      end
    end

    context "when there are no available connections, and the pool's max size has not been reached" do
      before do
        subject.connections.clear
        subject.connections.push(client)
      end

      it 'instantiates a new connection and returns it' do
        subject.check_out

        expect(Mysql2::Client).to receive(:new).with(default_options).and_return(client)
        expect(subject.check_out).to eq(client)
      end
    end

    context "when there are no available connections, and the pool's max size has been reached" do
      before do
        subject.connections.clear
        subject.instance_variable_set(:@created_connections, 5)

        5.times { subject.check_in(client) }
        5.times { subject.check_out }
      end

      it 'throws a RuntimeError' do
        expect { subject.check_out }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#check_in' do
    context 'when connection pooling is enabled' do
      it 'returns the provided client to the connection pool' do
        expect(subject.connections).to receive(:push).with(client)

        subject.check_in(client)
      end

      context 'when the connection has been closed by the server' do
        let(:closed_client) { double(close: true, closed?: true) }

        it 'instantiates a new connection and returns it' do
          expect(Mysql2::Client).to receive(:new).with(default_options).and_return(client)
          expect(subject.connections).to receive(:push).with(client)

          subject.check_in(closed_client)
        end
      end
    end

    context 'when connection pooling is disabled' do
      let(:connection_pooling_enabled) { 'false' }

      it 'closes the connection and does not add it to the connection pool' do
        expect(client).to receive(:close)
        expect(subject.connections).not_to receive(:push)

        subject.check_in(client)
      end
    end

    context 'when client is nil' do
      let(:client) { nil }

      context 'when connection pooling is enabled' do
        it 'does not raise an error' do
          expect { subject.check_in(client) }.not_to raise_error
        end
      end

      context 'when connection pooling is disabled' do
        let(:connection_pooling_enabled) { 'false' }

        it 'does not raise an error' do
          expect { subject.check_in(client) }.not_to raise_error
        end
      end
    end
  end

  describe '#with_client' do
    it 'uses the client that is provided, if passed one' do
      expect(subject).not_to receive(:check_out)
      expect { |b| subject.with_client(client, &b) }.to yield_with_args(client)
    end

    it 'obtains a client from the pool to use, if no client is provided' do
      allow(subject).to receive(:check_out).and_return(client)
      expect { |b| subject.with_client(&b) }.to yield_with_args(client)
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
    before(:each) { allow(subject).to receive(:check_out).and_return(client) }

    it 'retrieves a client and calls query' do
      expect(client).to receive(:query).with('SELECT 1')

      subject.query('SELECT 1')
    end

    it 'does not check out a new client when one is provided' do
      expect(subject).not_to receive(:check_out)
      expect(existing_client).to receive(:query).with('SELECT 1')

      subject.query('SELECT 1', existing_client)
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
    before(:each) { allow(subject).to receive(:check_out).and_return(client) }

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
