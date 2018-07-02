# frozen_string_literal: true

module MysqlFramework
  module Support
    module Scripts
      class CreateDemoTable < MysqlFramework::Scripts::Base
        def initialize
          @identifier = 201806021520 # 15:20 02/06/2018
        end

        def apply
          mysql_connector.query("
            CREATE TABLE IF NOT EXISTS `#{database_name}`.`demo` (
              `id` CHAR(36) NOT NULL,
              `name` VARCHAR(255) NULL,
              `created_at` DATETIME NOT NULL,

              `updated_at` DATETIME NOT NULL,
              PRIMARY KEY (`id`)
            )")
        end

        def rollback
          raise 'Rollback not supported in test.'
        end

        def tags
          [MysqlFramework::Support::Tables::DemoTable::NAME]
        end
      end
    end
  end
end
