# frozen_string_literal: true

module MysqlFramework
  module Support
    module Scripts
      class CreateDemoTable < MysqlFramework::Scripts::Base
        def initialize
          @identifier = 201806021520 # 15:20 02/06/2018
        end

        def apply(client)
          client.query(<<~SQL)
            CREATE TABLE IF NOT EXISTS `#{table_name}` (
              `id` CHAR(36) NOT NULL,
              `name` VARCHAR(255) NULL,
              `created_at` DATETIME NOT NULL,
              `updated_at` DATETIME NOT NULL,
              `partition` INT NOT NULL,
              PRIMARY KEY (`id`, `partition`)
            )
            PARTITION BY LIST(`partition`) (
              #{generate_partition_sql}
            )
          SQL
        end

        def rollback(_client)
          raise 'Rollback not supported in test.'
        end

        def tags
          [table_name]
        end

        private

        def table_name
          MysqlFramework::Support::Tables::DemoTable::NAME
        end
      end
    end
  end
end
