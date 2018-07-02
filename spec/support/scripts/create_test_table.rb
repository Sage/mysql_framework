# frozen_string_literal: true

module MysqlFramework
  module Support
    module Scripts
      class CreateTestTable < MysqlFramework::Scripts::Base
        def initialize
          @identifier = 201801011030 # 10:30 01/01/2018
        end

        def apply
          mysql_connector.query("
            CREATE TABLE IF NOT EXISTS `#{database_name}`.`test` (
              `id` CHAR(36) NOT NULL,
              `name` VARCHAR(255) NULL,
              `action` VARCHAR(255) NULL,
              `created_at` DATETIME NOT NULL,
              `updated_at` DATETIME NOT NULL,
              PRIMARY KEY (`id`)
            )")
        end

        def rollback
          raise 'Rollback not supported in test.'
        end

        def tags
          [MysqlFramework::Support::Tables::TestTable::NAME]
        end
      end
    end
  end
end
