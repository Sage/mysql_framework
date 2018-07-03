# frozen_string_literal: true

require 'spec_helper'

describe MysqlFramework::Scripts::Manager do
  let(:connector) { MysqlFramework::Connector.new }

  before :each do
    subject.instance_variable_set(:@mysql_connector, connector)
  end

  describe '#execute' do
    before :each do
      subject.initialize_script_history
    end

    it 'executes all pending scripts' do
      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(false)

      subject.execute

      expect(subject.table_exists?('demo')).to eq(true)
      expect(subject.table_exists?('test')).to eq(true)
    end

    after :each do
      subject.drop_all_tables
    end
  end

  describe '#apply_by_tag' do
    before :each do
      subject.initialize_script_history
    end

    it 'executes all pending scripts that match the tag' do
      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(false)

      subject.apply_by_tag([MysqlFramework::Support::Tables::TestTable::NAME])

      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(true)
    end

    after :each do
      subject.drop_all_tables
    end
  end

  describe '#drop_all_tables' do
    it 'drops the script history table and any registered tables' do
      expect(subject).to receive(:drop_script_history)
      expect(subject).to receive(:drop_table).with('test')
      expect(subject).to receive(:drop_table).with('demo')

      subject.drop_all_tables
    end
  end

  describe '#retrieve_last_executed_script' do
    before :each do
      subject.initialize_script_history
    end

    context 'when no scripts have been executed' do
      it 'returns 0' do
        expect(subject.retrieve_last_executed_script).to eq(0)
      end
    end

    context 'when scripts have been executed previously' do
      before :each do
        subject.apply_by_tag([MysqlFramework::Support::Tables::TestTable::NAME])
      end

      it 'returns the last executed script' do
        expect(subject.retrieve_last_executed_script).to eq(201807031200)
      end
    end

    after :each do
      subject.drop_script_history
    end
  end

  describe '#initialize_script_history' do
    it 'creates a migration history table' do
      expect(subject.table_exists?('migration_script_history')).to eq(false)
      subject.initialize_script_history
      expect(subject.table_exists?('migration_script_history')).to eq(true)
    end
  end

  describe '#calculate_pending_scripts' do
    it 'returns any scripts that are newer than the given date in ascending order' do
      timestamp = 201701010000 # 00:00 01/01/2017
      results = subject.calculate_pending_scripts(timestamp)

      expect(results.length).to eq(3)
      expect(results[0]).to be_a(MysqlFramework::Support::Scripts::CreateTestTable)
      expect(results[1]).to be_a(MysqlFramework::Support::Scripts::CreateDemoTable)
    end

    context 'when there are scripts older than the given date' do
      it 'returns only scripts that are newer than the given date in ascending order' do
        timestamp = 201802021010 # 10:10 02/02/2018
        results = subject.calculate_pending_scripts(timestamp)

        expect(results.length).to eq(2)
        expect(results[0]).to be_a(MysqlFramework::Support::Scripts::CreateDemoTable)
      end
    end
  end

  describe '#table_exists?' do
    context 'when the table exists' do
      it 'returns true' do
        expect(subject.table_exists?('gems')).to eq(true)
      end
    end

    context 'when the table does not exist' do
      it 'returns false' do
        expect(subject.table_exists?('foo')).to eq(false)
      end
    end
  end

  describe '#drop_script_history' do
    it 'drops the migration script history table' do
      query  = "DROP TABLE IF EXISTS `#{ENV.fetch('MYSQL_DATABASE')}`.`migration_script_history`"
      expect(connector).to receive(:query).with(query)
      subject.drop_script_history
    end
  end

  describe '#drop_table' do
    it 'drops the given table' do
      expect(connector).to receive(:query).with('DROP TABLE IF EXISTS `some_database`.`some_table`')
      subject.drop_table('`some_database`.`some_table`')
    end
  end

  describe '#all_tables' do
    it 'returns all registered tables' do
      expect(subject.all_tables).to eq(['test', 'demo'])
    end
  end

  describe '.all_tables' do
    it 'stores a class level array of tables' do
      expect(described_class.all_tables).to eq(['test', 'demo'])
    end
  end
end
