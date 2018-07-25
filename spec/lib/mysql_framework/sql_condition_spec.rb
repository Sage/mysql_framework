# frozen_string_literal: true

describe MysqlFramework::SqlCondition do
  subject { described_class.new(column: 'version', comparison: '=', value: '1.0.0') }

  describe '#to_s' do
    it 'returns the condition as a string for a prepared statement' do
      expect(subject.to_s).to eq('version = ?')
    end
  end
end
