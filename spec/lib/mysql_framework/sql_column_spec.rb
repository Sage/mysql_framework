# frozen_string_literal: true

describe MysqlFramework::SqlColumn do
  subject { described_class.new(table: 'gems', column: 'version') }

  describe '#to_s' do
    it 'returns the prepared sql name with backticks' do
      expect(subject.to_s).to eq('`gems`.`version`')
    end
  end

  describe '#to_sym' do
    it 'returns the column name as a symbol' do
      expect(subject.to_sym).to eq(:version)
    end
  end

  describe '#eq' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.eq('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` = ?')
    end
  end

  describe '#not_eq' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.not_eq('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` <> ?')
    end
  end

  describe '#gt' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.gt('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` > ?')
    end
  end

  describe '#gte' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.gte('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` >= ?')
    end
  end

  describe '#lt' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.lt('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` < ?')
    end
  end

  describe '#lte' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.lte('2.0.0')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` <= ?')
    end
  end

  describe '#as' do
    it 'returns the column specified as another name' do
      expect(subject.as('v')).to eq('`gems`.`version` as `v`')
    end
  end

  describe '#like' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.like('%foo%')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` LIKE ?')
    end
  end

  describe '#not_like' do
    it 'returns a SqlCondition for the comparison' do
      condition = subject.not_like('%foo%')
      expect(condition).to be_a(MysqlFramework::SqlCondition)
      expect(condition.to_s).to eq('`gems`.`version` NOT LIKE ?')
    end
  end
end
