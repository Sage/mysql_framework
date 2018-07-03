# frozen_string_literal: true

require 'spec_helper'

describe MysqlFramework::Scripts::Base do
  subject { described_class.new }

  describe '#partitions' do
    it 'returns the number of paritions' do
      expect(subject.partitions).to eq(5)
    end
  end

  describe '#database_name' do
    it 'returns the database name' do
      expect(subject.database_name).to eq('test_database')
    end
  end

  describe '#identifier' do
    it 'throws a NotImplementedError' do
      expect{ subject.identifier }.to raise_error(NotImplementedError)
    end

    context 'when @identifier is set' do
      it 'returns the value' do
        subject.instance_variable_set(:@identifier, 'foo')
        expect(subject.identifier).to eq('foo')
      end
    end
  end

  describe '#apply' do
    it 'throws a NotImplementedError' do
      expect{ subject.apply }.to raise_error(NotImplementedError)
    end
  end

  describe '#rollback' do
    it 'throws a NotImplementedError' do
      expect{ subject.rollback }.to raise_error(NotImplementedError)
    end
  end

  describe '#generate_partition_sql' do
    it 'generates the partition sql statement' do
      expected = "PARTITION p0 VALUES IN (0),\n\tPARTITION p1 VALUES IN (1),\n\tPARTITION p2 VALUES IN (2),\n\tPARTITION p3 VALUES IN (3),\n\tPARTITION p4 VALUES IN (4)"
      expect(subject.generate_partition_sql).to eq(expected)
    end
  end

  describe '.descendants' do
    it 'returns all descendant classes' do
      expect(described_class.descendants.length).to eq(3)
      expect(described_class.descendants).to include(MysqlFramework::Support::Scripts::CreateTestTable,
                                                     MysqlFramework::Support::Scripts::CreateDemoTable,
                                                     MysqlFramework::Support::Scripts::CreateTestProc)
    end
  end

  describe '#tags' do
    it 'returns an array' do
      expect(subject.tags).to eq([])
    end
  end

  describe '#update_procedure' do
    let(:connector) { MysqlFramework::Connector.new }
    let(:proc_file_path) { 'spec/support/procedure.sql' }
    let(:drop_sql) { "DROP PROCEDURE IF EXISTS GetAllVersions;" }

    before :each do
      subject.instance_variable_set(:@mysql_connector, connector)
    end

    it 'drops and then creates the named procedure' do
      expect(connector).to receive(:query).with(drop_sql).once
      expect(connector).to receive(:query).with(File.read(proc_file_path)).once
      subject.update_procedure('GetAllVersions', proc_file_path)
    end

    it 'wraps the call in a transaction' do
      expect(connector).to receive(:transaction)
      subject.update_procedure('GetAllVersions', proc_file_path)
    end
  end
end
