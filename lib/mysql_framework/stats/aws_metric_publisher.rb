# frozen_string_literal: true

require 'aws-sdk-cloudwatch'
require_relative 'dimension_map'

module MysqlFramework
  module Stats
    class AwsMetricPublisher
      THREAD_NAME = 'mysql-connector-pool-stats'
      JOIN_TIMEOUT = 5 # seconds to wait for clean thread exit before force-killing
      METRIC_UNIT = 'Count'
      METRIC_NAME_MAP = {
        size: 'MysqlConnectionPoolSize',
        available: 'MysqlConnectionPoolAvailable',
        idle: 'MysqlConnectionPoolIdle'
      }.freeze

      # Initializes AWS metric publishing dependencies.
      #
      # @param connector [MysqlFramework::Connector, nil] connector used to read connection-pool stats
      # @param dimension_map [MysqlFramework::Stats::DimensionMap, nil] CloudWatch namespace and dimensions
      # @param cloudwatch_client [Aws::CloudWatch::Client, nil] CloudWatch client instance
      # @param publish_interval [Integer] metric publish interval in seconds
      # @return [void]
      def initialize(
        connector: nil,
        dimension_map: nil,
        cloudwatch_client: nil,
        publish_interval: 300
      )
        @thread = nil
        @connector = connector
        @cloudwatch_client = cloudwatch_client
        @dimension_map = dimension_map || MysqlFramework::Stats::DimensionMap.new
        @publish_interval = publish_interval
      end

      # Spawns the background sampling thread. Safe to call more than once –
      # subsequent calls are no-ops while the thread is already running.
      #
      # @return [Thread, nil] reporter thread when started, or nil when already running
      def start
        return if running?

        thread = Thread.new do
          Thread.current.name = THREAD_NAME
          loop do
            sleep @publish_interval
            break unless Thread.current == @thread

            sample
          end
        end

        thread.abort_on_exception = false
        @thread = thread
      end

      # Cooperatively stops the background thread and waits up to JOIN_TIMEOUT
      # seconds for it to exit before force-killing it.
      #
      # @return [void]
      def stop
        thread = @thread
        @thread = nil # cooperative stop signal: loop checks this after each sleep
        thread&.join(JOIN_TIMEOUT)
        thread&.kill # force-kill only if still alive after timeout
      end

      # Returns true when the reporter thread is alive.
      #
      # @return [Boolean]
      def running?
        @thread&.alive? || false
      end

      private

      # Reads pool stats and publishes them to CloudWatch using a low-cardinality
      # dimension set so all ECS tasks for the same service aggregate together.
      # Errors are swallowed and logged so that a reporting failure never
      # propagates to the caller.
      def sample
        connection_pool = @connector&.connection_pool
        return if connection_pool.nil?

        stats = connection_pool.pool_stats
        metric_data = build_metric_data(stats)
        return if metric_data.empty?

        MysqlFramework.logger.debug { "[#{self.class}] - CloudWatch/#{@dimension_map.namespace} - #{stats.inspect}" }

        cloudwatch_client.put_metric_data(
          namespace: @dimension_map.namespace,
          metric_data: metric_data
        )
      rescue StandardError => e
        MysqlFramework.logger.error { "[#{self.class}] - Failed to record pool stats: #{e.message}" }
      end

      def build_metric_data(stats)
        timestamp = Time.now.utc

        METRIC_NAME_MAP.filter_map do |key, metric_name|
          value = stats[key]
          next if value.nil?

          {
            metric_name: metric_name,
            dimensions: @dimension_map.to_cloudwatch_dimensions,
            timestamp: timestamp,
            unit: METRIC_UNIT,
            value: value.to_f
          }
        end
      end

      def cloudwatch_client
        @cloudwatch_client ||= Aws::CloudWatch::Client.new
      end
    end
  end
end
