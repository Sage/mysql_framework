# frozen_string_literal: true

module MysqlFramework
  module Stats
    # Class to handle dimensions for AWS reporting
    class DimensionMap
      attr_accessor :service_name, :application, :environment, :landscape, :namespace

      # Initializes dimension values used for CloudWatch metrics.
      #
      # @param service_name [String, nil] service dimension
      # @param application [String, nil] application dimension
      # @param environment [String, nil] environment dimension
      # @param landscape [String, nil] landscape dimension
      # @param namespace [String, nil] CloudWatch namespace override
      # @return [void]
      def initialize(
        service_name: nil,
        application: nil,
        environment: nil,
        landscape: nil,
        namespace: nil
      )
        @service_name = service_name
        @application = application
        @environment = environment
        @landscape = landscape
        @namespace = namespace
      end

      # Builds CloudWatch dimensions from configured values or environment variables.
      #
      # @return [Array<Hash{Symbol => String}>] dimensions with non-nil values only
      def to_cloudwatch_dimensions
        [
          { name: 'ServiceName', value: service_name || ENV.fetch('SERVICE_NAME', nil) },
          { name: 'Application', value: application || ENV.fetch('APPLICATION', nil) },
          { name: 'Environment', value: environment || ENV.fetch('ENVIRONMENT', nil) },
          { name: 'Landscape', value: landscape || ENV.fetch('LANDSCAPE', nil) }
        ].reject { |dimension| dimension[:value].nil? }
      end

      # Returns the CloudWatch namespace.
      #
      # @return [String] configured namespace or default namespace value
      def namespace
        @namespace || ENV.fetch('AWS_METRICS_NAMESPACE', 'MysqlFramework')
      end
    end
  end
end
