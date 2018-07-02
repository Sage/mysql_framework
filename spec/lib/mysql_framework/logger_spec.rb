# frozen_string_literal: true

require 'spec_helper'

describe MysqlFramework do
  describe 'logger' do
    it 'returns the logger' do
      expect(subject.logger).to be_a(Logger)
    end
  end

  describe 'set_logger' do
    let(:logger) { Logger.new(STDOUT) }

    it 'sets the logger' do
      subject.set_logger(logger)
      expect(subject.logger).to eq(logger)
    end
  end
end
