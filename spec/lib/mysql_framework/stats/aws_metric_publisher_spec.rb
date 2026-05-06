# frozen_string_literal: true

require 'spec_helper'
require 'mysql_framework/stats/aws_metric_publisher'

describe MysqlFramework::Stats::AwsMetricPublisher do
  let(:connection_pool) { instance_double(MysqlFramework::MysqlConnectionPool, pool_stats: stats) }
  let(:connector) { instance_double(MysqlFramework::Connector, connection_pool: connection_pool) }
  let(:stats) { { size: 5, available: 3, idle: 2 } }
  let(:dimensions) do
    [
      { name: 'ServiceName', value: 'mysql-framework' },
      { name: 'Environment', value: 'test' }
    ]
  end
  let(:dimension_map) do
    instance_double(
      MysqlFramework::Stats::DimensionMap,
      namespace: 'MysqlFramework',
      to_cloudwatch_dimensions: dimensions
    )
  end
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }
  let(:logger) { instance_double(Logger, debug: nil, error: nil) }

  subject(:reporter) do
    described_class.new(
      connector: connector,
      dimension_map: dimension_map,
      cloudwatch_client: cloudwatch_client,
      publish_interval: 1
    )
  end

  before do
    allow(MysqlFramework).to receive(:logger).and_return(logger)
    allow(ENV).to receive(:fetch).and_call_original
  end

  describe '#sample' do
    it 'publishes connector pool stats to CloudWatch' do
      expect(cloudwatch_client).to receive(:put_metric_data) do |payload|
        expect(payload[:namespace]).to eq('MysqlFramework')
        expect(payload[:metric_data].size).to eq(3)

        size_metric = payload[:metric_data].find { |metric| metric[:metric_name] == 'MysqlConnectionPoolSize' }
        available_metric = payload[:metric_data].find { |metric| metric[:metric_name] == 'MysqlConnectionPoolAvailable' }
        idle_metric = payload[:metric_data].find { |metric| metric[:metric_name] == 'MysqlConnectionPoolIdle' }

        expect(size_metric[:value]).to eq(5.0)
        expect(available_metric[:value]).to eq(3.0)
        expect(idle_metric[:value]).to eq(2.0)
        expect(size_metric[:dimensions]).to eq(dimensions)
        expect(size_metric[:unit]).to eq('Count')
      end

      reporter.send(:sample)
    end

    it 'does not publish when connector is nil' do
      subject = described_class.new(
        connector: nil,
        dimension_map: dimension_map,
        cloudwatch_client: cloudwatch_client
      )

      expect(cloudwatch_client).not_to receive(:put_metric_data)

      subject.send(:sample)
    end

    it 'logs an error when cloudwatch publish raises' do
      allow(cloudwatch_client).to receive(:put_metric_data).and_raise(StandardError, 'aws unavailable')
      expect(logger).to receive(:error)

      reporter.send(:sample)
    end
  end

  describe '#build_metric_data' do
    it 'skips nil values in stats map' do
      data = reporter.send(:build_metric_data, size: 1, available: nil, idle: 0)

      expect(data.size).to eq(2)
      names = data.map { |metric| metric[:metric_name] }
      expect(names).to contain_exactly('MysqlConnectionPoolSize', 'MysqlConnectionPoolIdle')
    end
  end
end
