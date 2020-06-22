# frozen_string_literal: true

describe MysqlFramework::SqlCondition do
  subject { described_class.new(column: 'version', comparison: '=', value: '1.0.0') }

  describe '#to_s' do
    it 'returns the condition as a string for a prepared statement' do
      expect(subject.to_s).to eq('version = ?')
    end
  end

  context 'when comparison is neither IS NULL or IS NOT NULL' do
    context 'when value is nil' do
      subject { described_class.new(column: 'version', comparison: '=', value: nil) }

      it 'does raises an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, "Comparison of = requires value to be not nil")
      end
    end
  end

  context 'when comparison is IS NULL' do
    subject { described_class.new(column: 'version', comparison: 'IS NULL') }

    it 'has a nil value by default' do
      expect(subject.value).to be_nil
    end

    context 'when a value is passed to the constructor' do
      subject { described_class.new(column: 'version', comparison: 'IS NULL', value: 'foo') }

      describe '#new' do
        it 'raises an ArgumentError if value is set' do
          expect { subject }.to raise_error(ArgumentError, 'Cannot set value when comparison is IS NULL')
        end
      end
    end

    describe '#to_s' do
      it 'does not include a value placeholder' do
        expect(subject.to_s).to eq('version IS NULL')
      end
    end
  end

  context 'when comparison is lowercase is null' do
    subject { described_class.new(column: 'version', comparison: 'is null') }

    describe '#to_s' do
      it 'ignores case' do
        expect(subject.to_s).to eq 'version IS NULL'
      end
    end
  end

  context 'when comparison is IS NOT NULL' do
    subject { described_class.new(column: 'version', comparison: 'IS NOT NULL') }

    it 'has a nil value by default' do
      expect(subject.value).to be_nil
    end

    context 'when a value is passed to the constructor' do
      subject { described_class.new(column: 'version', comparison: 'IS NOT NULL', value: 'foo') }

      describe '#new' do
        it 'raises an ArgumentError if value is set' do
          expect { subject }.to raise_error(ArgumentError, 'Cannot set value when comparison is IS NOT NULL')
        end
      end
    end

    describe '#to_s' do
      it 'does not include a value placeholder' do
        expect(subject.to_s).to eq('version IS NOT NULL')
      end
    end
  end

  context 'when comparison is lowercase is not null' do
    subject { described_class.new(column: 'version', comparison: 'is not null') }

    describe '#to_s' do
      it 'ignores case' do
        expect(subject.to_s).to eq 'version IS NOT NULL'
      end
    end
  end
end
