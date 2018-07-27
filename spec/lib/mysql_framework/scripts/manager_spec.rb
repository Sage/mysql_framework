# frozen_string_literal: true

describe MysqlFramework::Scripts::Manager do
  let(:connector) do
    connector = MysqlFramework::Connector.new
    connector.setup
    connector
  end

  subject { described_class.new(connector) }

  describe '#execute' do
    before(:each) do
      subject.drop_all_tables
      subject.initialize_script_history
    end
    after(:each) { subject.drop_all_tables }

    it 'executes all pending scripts' do
      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(false)

      subject.execute

      expect(subject.table_exists?('demo')).to eq(true)
      expect(subject.table_exists?('test')).to eq(true)
    end
  end

  describe '#apply_by_tag' do
    before(:each) do
      subject.drop_all_tables
      subject.initialize_script_history
    end
    after(:each) { subject.drop_all_tables }

    it 'executes all pending scripts that match the tag' do
      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(false)

      subject.apply_by_tag([MysqlFramework::Support::Tables::TestTable::NAME])

      expect(subject.table_exists?('demo')).to eq(false)
      expect(subject.table_exists?('test')).to eq(true)
    end
  end

  describe '#retrieve_executed_scripts' do
    before(:each) { subject.initialize_script_history }

    context 'when no scripts have been executed' do
      it 'returns an empty array' do
        expect(subject.retrieve_executed_scripts).to be_a(Array)
        expect(subject.retrieve_executed_scripts).to be_empty
      end
    end

    context 'when scripts have been executed previously' do
      before(:each) { subject.apply_by_tag([MysqlFramework::Support::Tables::TestTable::NAME]) }
      after(:each) { subject.drop_script_history }

      it 'returns the last executed script' do
        expect(subject.retrieve_executed_scripts).to eq([201807031200, 201801011030])
      end
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
    before(:each) { subject.drop_script_history }

    context 'no migrations have been run' do
      it 'returns all scripts that are missing in ascending order' do
        results = subject.calculate_pending_scripts([])

        expect(results.length).to eq(3)
        expect(results[0]).to be_a(MysqlFramework::Support::Scripts::CreateTestTable)
        expect(results[1]).to be_a(MysqlFramework::Support::Scripts::CreateDemoTable)
        expect(results[2]).to be_a(MysqlFramework::Support::Scripts::CreateTestProc)
      end
    end

    context 'some migrations have been run' do
      it 'returns any scripts that are missing in ascending order' do
        timestamp = 201806021520
        results = subject.calculate_pending_scripts([timestamp])

        expect(results.length).to eq(2)
        expect(results[0]).to be_a(MysqlFramework::Support::Scripts::CreateTestTable)
        expect(results[1]).to be_a(MysqlFramework::Support::Scripts::CreateTestProc)
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

  describe '#drop_all_tables' do
    it 'drops the script history table and any registered tables' do
      expect(subject).to receive(:drop_script_history)
      expect(subject).to receive(:drop_table).with('test')
      expect(subject).to receive(:drop_table).with('demo')

      subject.drop_all_tables
    end
  end

  describe '#drop_script_history' do
    it 'drops the migration script history table' do
      query = <<~SQL
        DROP TABLE IF EXISTS `#{ENV.fetch('MYSQL_MIGRATION_TABLE', 'migration_script_history')}`
      SQL
      expect(connector).to receive(:query).with(query)
      subject.drop_script_history
    end
  end

  describe '#drop_table' do
    it 'drops the given table' do
      expect(connector).to receive(:query).with(<<~SQL)
        DROP TABLE IF EXISTS `some_table`
      SQL
      subject.drop_table('some_table')
    end
  end

  describe '#all_tables' do
    it 'returns all registered tables' do
      expect(subject.all_tables).to eq(%w(test demo))
    end
  end

  describe '.all_tables' do
    it 'stores a class level array of tables' do
      expect(described_class.all_tables).to eq(%w(test demo))
    end
  end
end
