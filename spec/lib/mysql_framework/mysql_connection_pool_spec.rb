# frozen_string_literal: true

describe MysqlFramework::MysqlConnectionPool do
  let(:options) do
    {
      host: ENV.fetch('MYSQL_HOST'),
      port: ENV.fetch('MYSQL_PORT'),
      database: ENV.fetch('MYSQL_DATABASE'),
      username: ENV.fetch('MYSQL_USERNAME'),
      password: ENV.fetch('MYSQL_PASSWORD'),
      reconnect: true
    }
  end
  let(:conn) do
    double('Mysql2::Client',
           ping: true,
           abandon_results!: nil,
           query: nil,
           close: nil,
           closed?: false)
  end
  let(:pool) do
    double('ConnectionPool',
           checkout: conn,
           checkin: nil,
           discard_current_connection: nil,
           shutdown: nil,
           size: 5,
           available: 4,
           idle: 1)
  end

  subject { described_class.new(options) }

  after { subject.dispose }

  describe '#initialize' do
    it 'stores the provided options' do
      expect(subject.instance_variable_get(:@options)).to eq(options)
    end

    it 'creates a setup mutex' do
      expect(subject.instance_variable_get(:@setup_mutex)).to be_a(Mutex)
    end
  end

  describe '#setup' do
    it 'creates a ConnectionPool' do
      subject.setup
      expect(subject.connections).to be_a(ConnectionPool)
    end

    it 'is idempotent — calling setup twice keeps the same pool' do
      subject.setup
      first_pool = subject.connections
      subject.setup
      expect(subject.connections).to equal(first_pool)
    end

    it 'starts the idle connection cleaner thread' do
      subject.setup
      threads = Thread.list.map(&:name)
      expect(threads).to include(MysqlFramework::MysqlConnectionPool::CLEAN_IDLE_CONNECTIONS_THREAD_NAME)
    end
  end

  describe '#dispose' do
    before { subject.setup }

    it 'shuts down the connection pool' do
      subject.dispose
      expect(subject.connections).to be_nil
    end

    it 'is safe to call when already disposed' do
      subject.dispose
      expect { subject.dispose }.not_to raise_error
    end

    it 'stops the idle connection cleaner thread' do
      thread = subject.instance_variable_get(:@idle_connections_thread)
      subject.dispose
      expect(thread).not_to be_alive
    end
  end

  describe '#pool_stats' do
    context 'when connections have not been set up' do
      it 'returns zero stats' do
        expect(subject.pool_stats).to eq(size: 0, available: 0, idle: 0)
      end
    end

    context 'when connections are set up' do
      before { subject.instance_variable_set(:@connections, pool) }

      it 'returns size, available, and idle metrics from the pool' do
        expect(subject.pool_stats).to eq(size: 5, available: 4, idle: 1)
      end
    end
  end

  describe '#check_out' do
    before do
      subject.instance_variable_set(:@connections, pool)
      allow(conn).to receive(:query).with('ROLLBACK')
    end

    it 'returns a sanitized connection from the pool' do
      expect(subject.check_out).to eq(conn)
    end

    it 'sanitizes the connection before returning it' do
      expect(conn).to receive(:ping)
      expect(conn).to receive(:abandon_results!)
      expect(conn).to receive(:query).with('ROLLBACK')
      subject.check_out
    end

    context 'when sanitization raises ConnectionSanitizationError' do
      before { allow(conn).to receive(:ping).and_raise(Mysql2::Error.new('gone away')) }

      it 'retries the checkout once before raising' do
        expect(pool).to receive(:checkout).twice.and_return(conn)
        expect { subject.check_out }.to raise_error(MysqlFramework::MysqlConnectionPool::ConnectionSanitizationError)
      end

      it 'discards the connection on each sanitization failure' do
        expect(pool).to receive(:discard_current_connection).at_least(:twice)
        expect { subject.check_out }.to raise_error(MysqlFramework::MysqlConnectionPool::ConnectionSanitizationError)
      end
    end

    context 'when checkout raises Mysql2::Error' do
      before { allow(pool).to receive(:checkout).and_raise(Mysql2::Error.new('connection refused')) }

      it 'discards the current connection' do
        expect(pool).to receive(:discard_current_connection)
        expect { subject.check_out }.to raise_error(Mysql2::Error)
      end

      it 're-raises the error' do
        allow(pool).to receive(:discard_current_connection)
        expect { subject.check_out }.to raise_error(Mysql2::Error)
      end
    end
  end

  describe '#check_in' do
    before { subject.instance_variable_set(:@connections, pool) }

    it 'returns immediately and does not interact with the pool when client is nil' do
      expect(pool).not_to receive(:checkin)
      expect(pool).not_to receive(:discard_current_connection)
      subject.check_in(nil)
    end

    context 'when the client is closed' do
      let(:closed_conn) { double('Mysql2::Client', closed?: true) }

      it 'discards the current pool connection' do
        expect(pool).to receive(:discard_current_connection)
        allow(pool).to receive(:checkin)
        subject.check_in(closed_conn)
      end
    end

    context 'when the client is open' do
      it 'checks the connection back into the pool' do
        expect(pool).to receive(:checkin)
        subject.check_in(conn)
      end

      it 'does not discard the connection' do
        expect(pool).not_to receive(:discard_current_connection)
        subject.check_in(conn)
      end
    end
  end

  describe '#with_client' do
    before do
      subject.instance_variable_set(:@connections, pool)
      allow(conn).to receive(:query).with('ROLLBACK')
      allow(pool).to receive(:with).and_yield(conn)
    end

    it 'yields a sanitized connection' do
      expect { |b| subject.with_client(&b) }.to yield_with_args(conn)
    end

    it 'returns the block result' do
      result = subject.with_client { |_c| :expected }
      expect(result).to eq(:expected)
    end

    it 'sanitizes the connection before yielding' do
      expect(conn).to receive(:ping)
      expect(conn).to receive(:abandon_results!)
      expect(conn).to receive(:query).with('ROLLBACK')
      subject.with_client { |_c| nil }
    end

    context 'when discard_current_pool_connection is false (default)' do
      it 'does not discard the connection after a successful block' do
        expect(pool).not_to receive(:discard_current_connection)
        subject.with_client { |_c| nil }
      end
    end

    context 'when discard_current_pool_connection is true' do
      it 'discards the current connection after the block completes' do
        expect(pool).to receive(:discard_current_connection)
        subject.with_client(discard_current_pool_connection: true) { |_c| nil }
      end
    end

    context 'when sanitization raises ConnectionSanitizationError' do
      before { allow(conn).to receive(:ping).and_raise(Mysql2::Error.new('gone away')) }

      it 'retries the pool checkout once before raising' do
        expect(pool).to receive(:with).twice.and_yield(conn)
        expect { subject.with_client { |_c| nil } }.to raise_error(MysqlFramework::MysqlConnectionPool::ConnectionSanitizationError)
      end

      it 'discards the connection on each sanitization failure' do
        allow(pool).to receive(:with).and_yield(conn)
        expect(pool).to receive(:discard_current_connection).at_least(:once)
        expect { subject.with_client { |_c| nil } }.to raise_error(MysqlFramework::MysqlConnectionPool::ConnectionSanitizationError)
      end
    end

    context 'when the block raises Mysql2::Error' do
      it 'discards the current connection' do
        expect(pool).to receive(:discard_current_connection)
        expect { subject.with_client { |_c| raise Mysql2::Error.new('lost connection') } }.to raise_error(Mysql2::Error)
      end

      it 're-raises the error' do
        allow(pool).to receive(:discard_current_connection)
        expect { subject.with_client { |_c| raise Mysql2::Error.new('lost connection') } }.to raise_error(Mysql2::Error)
      end

      it 'does not retry for Mysql2::Error raised in the block' do
        expect(pool).to receive(:with).once.and_yield(conn)
        allow(pool).to receive(:discard_current_connection)
        expect { subject.with_client { |_c| raise Mysql2::Error.new('lost connection') } }.to raise_error(Mysql2::Error)
      end
    end
  end
end
