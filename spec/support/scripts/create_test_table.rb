# frozen_string_literal: true

module MysqlFramework
  module Support
    module Scripts
      class CreateTestTable < MysqlFramework::Scripts::Base
        def initialize
          @identifier = 201801011030 # 10:30 01/01/2018
        end

        def apply(client)
          client.query(<<~SQL)
            CREATE TABLE IF NOT EXISTS `#{table_name}` (
              `id` CHAR(36) NOT NULL,
              `name` VARCHAR(255) NULL,
              `action` VARCHAR(255) NULL,
              `created_at` DATETIME NOT NULL,
              `updated_at` DATETIME NOT NULL,
              PRIMARY KEY (`id`)
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
          MysqlFramework::Support::Tables::TestTable::NAME
        end
      end
    end
  end
end
