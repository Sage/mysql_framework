# frozen_string_literal: true

module MysqlFramework
  module Support
    class Fixtures
      def self.execute
        connector = MysqlFramework::Connector.new(
          host: ENV.fetch('MYSQL_HOST'),
          port: ENV.fetch('MYSQL_PORT'),
          database: nil,
          username: ENV.fetch('MYSQL_USERNAME'),
          password: ENV.fetch('MYSQL_PASSWORD')
        )
        connector.setup

        client = connector.check_out

        client.query("DROP DATABASE IF EXISTS `#{ENV.fetch('MYSQL_DATABASE')}`;")
        client.query("DROP DATABASE IF EXISTS `#{ENV.fetch('MYSQL_DATABASE')}_2`;")
        client.query("CREATE DATABASE `#{ENV.fetch('MYSQL_DATABASE')}`;")
        client.query("CREATE DATABASE `#{ENV.fetch('MYSQL_DATABASE')}_2`;")
        client.query("USE `#{ENV.fetch('MYSQL_DATABASE')}`;")
        client.query(<<~SQL)
          CREATE TABLE `gems` (
            `id` CHAR(36) NOT NULL,
            `name` VARCHAR(255) NULL,
            `author` VARCHAR(255) NULL,
            `created_at` DATETIME,
            `updated_at` DATETIME,
            PRIMARY KEY (`id`)
          )
        SQL
        client.query(<<~SQL)
          INSERT INTO `gems`
          (`id`, `name`, `author`, `created_at`, `updated_at`)
          VALUES
          ('#{SecureRandom.uuid}', 'mysql_framework', 'Sage', NOW(), NOW()),
          ('#{SecureRandom.uuid}', 'sinject', 'Sage', NOW(), NOW())
        SQL

        connector.check_in(client)

        manager = MysqlFramework::Scripts::Manager.new(connector)
        manager.execute

        connector.dispose
      end
    end
  end
end
