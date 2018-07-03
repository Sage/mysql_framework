# frozen_string_literal: true

require 'spec_helper'

describe MysqlFramework::Connector do
  let(:default_options) do
    {
      host:      ENV.fetch('MYSQL_HOST'),
      port:      ENV.fetch('MYSQL_PORT'),
      database:  ENV.fetch('MYSQL_DATABASE'),
      username:  ENV.fetch('MYSQL_USERNAME'),
      password:  ENV.fetch('MYSQL_PASSWORD'),
      reconnect: true
    }
  end
  let(:options) do
    {
      host:     'host',
      port:     'port',
      database: 'database',
      username: 'username',
      password: 'password',
      reconnect: true
    }
  end
  let(:client) { double }
  let(:gems) { MysqlFramework::SqlTable.new('gems') }

  subject { described_class.new }

  describe '#initialize' do
    it 'sets default query options on the Mysql2 client' do
      subject
      expect(Mysql2::Client.default_query_options[:symbolize_keys]).to eq(true)
      expect(Mysql2::Client.default_query_options[:cast_booleans]).to eq(true)
    end

    context 'when options are provided' do
      subject { described_class.new(options) }

      it 'allows the default options to be overridden' do
        expect(subject.instance_variable_get(:@options)).to eq(options)
      end
    end
  end

  describe '#check_out' do
    it 'returns a Mysql2::Client instance from the pool' do
      expect(Mysql2::Client).to receive(:new).with(default_options).and_return(client)
      expect(subject.check_out).to eq(client)
    end

    context 'when the connection pool has a client available' do
      it 'returns a client instance from the pool' do
        subject.instance_variable_get(:@connection_pool).push(client)
        expect(subject.check_out).to eq(client)
      end
    end
  end

  describe '#check_in' do
    it 'returns the provided client to the connection pool' do
      expect(subject.instance_variable_get(:@connection_pool)).to receive(:push).with(client)
      subject.check_in(client)
    end
  end

  describe '#with_client' do
    it 'obtains a client from the pool to use' do
      allow(subject).to receive(:check_out).and_return(client)
      expect { |b| subject.with_client(&b) }.to yield_with_args(client)
    end
  end

  describe '#execute' do
    let(:insert_query) do
      MysqlFramework::SqlQuery.new.insert(gems)
        .into(
          gems[:id],
          gems[:name],
          gems[:author],
          gems[:created_at],
          gems[:updated_at]
        )
        .values(
          SecureRandom.uuid,
          'mysql_framework',
          'sage',
          Time.now,
          Time.now
        )
    end

    it 'executes the query with parameters' do
      guid = insert_query.params[0]
      subject.execute(insert_query)

      results = subject.query("SELECT * FROM `gems` WHERE id = '#{guid}';").to_a
      expect(results.length).to eq(1)
      expect(results[0][:id]).to eq(guid)
    end
  end

  describe '#query' do
    before :each do
      allow(subject).to receive(:check_out).and_return(client)
    end

    it 'retrieves a client and calls query' do
      expect(client).to receive(:query).with('SELECT 1')
      subject.query('SELECT 1')
    end
  end

  describe '#query_multiple_results' do
    let(:test) { MysqlFramework::SqlTable.new('test') }
    let(:manager) { MysqlFramework::Scripts::Manager.new }
    let(:connector) { MysqlFramework::Connector.new }
    let(:timestamp) { Time.at(628232400) } # 1989-11-28 00:00:00 -0500
    let(:guid) { 'a3ccb138-48ae-437a-be52-f673beb12b51' }
    let(:insert) do
      MysqlFramework::SqlQuery.new.insert(test)
        .into(test[:id],test[:name],test[:action],test[:created_at],test[:updated_at])
        .values(guid,'name','action',timestamp,timestamp)
    end
    let(:obj) do
      {
        id: guid,
        name: 'name',
        action: 'action',
        created_at: timestamp,
        updated_at: timestamp,
      }
    end

    before :each do
      manager.initialize_script_history
      manager.execute

      connector.execute(insert)
    end

    after :each do
      manager.drop_all_tables
    end

    it 'returns the results from the stored procedure' do
      query = "call test_procedure"
      result = subject.query_multiple_results(query)
      expect(result).to be_a(Array)
      expect(result.length).to eq(2)
      expect(result[0]).to eq([])
      expect(result[1]).to eq([obj])
    end
  end

  describe '#transaction' do
    before :each do
      allow(subject).to receive(:check_out).and_return(client)
    end

    it 'wraps the client call with BEGIN and COMMIT statements' do
      expect(client).to receive(:query).with('BEGIN')
      expect(client).to receive(:query).with('SELECT 1')
      expect(client).to receive(:query).with('COMMIT')

      subject.transaction do
        subject.query('SELECT 1')
      end
    end

    context 'when an exception occurs' do
      it 'triggers a ROLLBACK' do
        expect(client).to receive(:query).with('BEGIN')
        expect(client).to receive(:query).with('ROLLBACK')

        begin
          subject.transaction do
            raise
          end
        rescue
        end
      end
    end
  end

  describe '#default_options' do
    it 'returns the default options' do
      expect(subject.default_options).to eq(default_options)
    end
  end
end
