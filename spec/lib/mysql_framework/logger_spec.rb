# frozen_string_literal: true

describe MysqlFramework do
  describe 'logger' do
    it 'returns the logger' do
      expect(subject.logger).to be_a(Logger)
    end
  end

  describe 'logger=' do
    let(:logger) { Logger.new(STDOUT) }

    it 'sets the logger' do
      subject.logger = logger
      expect(subject.logger).to eq(logger)
    end
  end
end
