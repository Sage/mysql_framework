# frozen_string_literal: true

describe MysqlFramework::Scripts::Base do
  let(:client) { double }

  subject { described_class.new }

  describe '#identifier' do
    it 'throws a NotImplementedError' do
      expect { subject.identifier }.to raise_error(NotImplementedError)
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
      expect { subject.apply(client) }.to raise_error(NotImplementedError)
    end
  end

  describe '#rollback' do
    it 'throws a NotImplementedError' do
      expect { subject.rollback(client) }.to raise_error(NotImplementedError)
    end
  end

  describe '.descendants' do
    it 'returns all descendant classes' do
      expect(described_class.descendants.length).to eq(3)
      expect(described_class.descendants).to include(
        MysqlFramework::Support::Scripts::CreateTestTable,
        MysqlFramework::Support::Scripts::CreateDemoTable,
        MysqlFramework::Support::Scripts::CreateTestProc
      )
    end
  end

  describe '#tags' do
    it 'returns an array' do
      expect(subject.tags).to eq([])
    end
  end

  describe '#update_procedure' do
    let(:proc_file_path) { 'spec/support/procedure.sql' }
    let(:drop_sql) do
      <<~SQL
        DROP PROCEDURE IF EXISTS test_procedure;
      SQL
    end

    it 'drops and then creates the named procedure' do
      expect(client).to receive(:query).with(drop_sql).once
      expect(client).to receive(:query).with(File.read(proc_file_path)).once

      subject.update_procedure(client, 'test_procedure', proc_file_path)
    end
  end

  describe '#column_exists?' do
    it 'returns true when column exists' do
      expect(client).to receive(:query).and_return(['result'])
      expect(subject.column_exists?(client,'foo','bar')).to eq(true)
    end

    it 'returns false when column does not exist' do
      expect(client).to receive(:query).and_return([])
      expect(subject.column_exists?(client,'foo','bar')).to eq(false)
    end
  end

  describe '#index_exists?' do
    it 'returns true when index exists' do
      expect(client).to receive(:query).and_return(['result'])
      expect(subject.index_exists?(client,'foo','bar')).to eq(true)
    end

    it 'returns false when index does not exist' do
      expect(client).to receive(:query).and_return([])
      expect(subject.index_exists?(client,'foo','bar')).to eq(false)
    end
  end
end
