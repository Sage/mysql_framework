# frozen_string_literal: true

require 'spec_helper'

describe MysqlFramework::SqlTable do
  let(:table) { described_class.new('gems') }

  describe '#[](column)' do
    it 'returns a new SqlColumn class for the specified column' do
      expect(table[:version]).to be_a(MysqlFramework::SqlColumn)
      expect(table[:version].to_s).to eq('`gems`.`version`')
    end
  end

  describe '#to_s' do
    it 'returns the tablename wrapped in backticks' do
      expect(table.to_s).to eq('`gems`')
    end
  end

  describe '#to_sym' do
    it 'returns the table name as a symbol' do
      expect(table.to_sym).to eq(:gems)
    end
  end
end
