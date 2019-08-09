# frozen_string_literal: true

module MysqlFramework
  module Scripts
    class Base
      def identifier
        raise NotImplementedError if @identifier.nil?
        @identifier
      end

      def apply(_client)
        raise NotImplementedError
      end

      def rollback(_client)
        raise NotImplementedError
      end

      def self.descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end

      def tags
        []
      end

      def update_procedure(client, proc_name, proc_file)
        client.query(<<~SQL)
          DROP PROCEDURE IF EXISTS #{proc_name};
        SQL

        proc_sql = File.read(proc_file)

        client.query(proc_sql)
      end

      def column_exists?(client, table_name, column_name)
        result = client.query(<<~SQL)
          SHOW COLUMNS FROM "#{table_name}" WHERE Field="#{column_name}";
        SQL

        result.count == 1
      end

      def index_exists?(client, table_name, index_name)
        result = client.query(<<~SQL)
          SHOW INDEX FROM "#{table_name}" WHERE Key_name="#{index_name}" LIMIT 1;
        SQL

        result.count == 1
      end

      protected

      def generate_partition_sql
        (1..partitions).each_with_index.map { |_, i| "PARTITION p#{i} VALUES IN (#{i})" }.join(",\n\t")
      end

      private

      def partitions
        @partitions ||= Integer(ENV.fetch('MYSQL_PARTITIONS', '500'))
      end
    end
  end
end
