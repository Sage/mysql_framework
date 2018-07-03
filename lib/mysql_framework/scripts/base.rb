# frozen_string_literal: true

module MysqlFramework
  module Scripts
    class Base
      def partitions
        ENV.fetch('MYSQL_PARTITIONS', '500').to_i
      end

      def database_name
        @database_name ||= ENV.fetch('MYSQL_DATABASE')
      end

      def identifier
        raise NotImplementedError if @identifier.nil?
        @identifier
      end

      def apply
        raise NotImplementedError
      end

      def rollback
        raise NotImplementedError
      end

      def generate_partition_sql
        (1..partitions).each_with_index.map { |_, i| "PARTITION p#{i} VALUES IN (#{i})" }.join(",\n\t")
      end

      def self.descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end

      def tags
        []
      end

      def update_procedure(proc_name, proc_file)
        mysql_connector.transaction do
          mysql_connector.query("DROP PROCEDURE IF EXISTS #{proc_name};")

          proc_sql = File.read(proc_file)

          mysql_connector.query(proc_sql)
        end
      end

      private

      def mysql_connector
        @mysql_connector ||= MysqlFramework::Connector.new
      end
    end
  end
end
