# frozen_string_literal: true

module MysqlFramework
  module Scripts
    class Manager
      def initialize(mysql_connector)
        @mysql_connector = mysql_connector
      end

      def execute
        lock_manager.lock(self.class, migration_ttl) do |locked|
          raise unless locked

          initialize_script_history

          executed_scripts = retrieve_executed_scripts

          mysql_connector.transaction do |client|
            pending_scripts = calculate_pending_scripts(executed_scripts)
            MysqlFramework.logger.info do
              "[#{self.class}] - #{pending_scripts.length} pending data store scripts found."
            end

            pending_scripts.each { |script| apply(script, client) }
          end

          MysqlFramework.logger.debug { "[#{self.class}] - Migration script execution complete." }
        end
      end

      def apply_by_tag(tags)
        lock_manager.lock(self.class, migration_ttl) do |locked|
          raise unless locked

          initialize_script_history

          mysql_connector.transaction do |client|
            pending_scripts = calculate_pending_scripts
            MysqlFramework.logger.info do
              "[#{self.class}] - #{pending_scripts.length} pending data store scripts found."
            end

            pending_scripts.reject { |script| (script.tags & tags).empty? }.sort_by(&:identifier)
              .each { |script| apply(script, client) }
          end

          MysqlFramework.logger.debug { "[#{self.class}] - Migration script execution complete." }
        end
      end

      def retrieve_executed_scripts
        MysqlFramework.logger.debug { "[#{self.class}] - Retrieving last executed script from history." }

        results = mysql_connector.query(<<~SQL)
          SELECT `identifier` FROM `#{migration_table_name}` ORDER BY `identifier` DESC
        SQL

        results.to_a.map { |result| result[:identifier]&.to_i }
      end

      def initialize_script_history
        MysqlFramework.logger.debug { "[#{self.class}] - Initializing script history." }

        mysql_connector.query(<<~SQL)
          CREATE TABLE IF NOT EXISTS `#{migration_table_name}` (
            `identifier` CHAR(15) NOT NULL,
            `timestamp` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`),
            UNIQUE INDEX `identifier_UNIQUE` (`identifier` ASC)
          )
        SQL
      end

      def calculate_pending_scripts(executed_scripts = [])
        MysqlFramework.logger.debug { "[#{self.class}] - Calculating pending data store scripts." }

        migrations.map(&:new).reject { |script| executed_scripts.include?(script.identifier) }.sort_by(&:identifier)
      end

      def table_exists?(table_name)
        result = mysql_connector.query(<<~SQL)
          SHOW TABLES LIKE '#{table_name}'
        SQL

        result.count == 1
      end

      def drop_all_tables
        drop_script_history
        all_tables.each { |table| drop_table(table) }
      end

      def drop_script_history
        drop_table(migration_table_name)
      end

      def drop_table(table_name)
        mysql_connector.query(<<~SQL)
          DROP TABLE IF EXISTS `#{table_name}`
        SQL
      end

      def all_tables
        self.class.all_tables
      end

      def self.all_tables
        @all_tables ||= []
      end

      private

      attr_reader :mysql_connector

      def lock_manager
        @lock_manager ||= Redlock::Client.new([ENV.fetch('REDIS_URL')])
      end

      def migration_ttl
        @migration_ttl ||= ENV.fetch('MYSQL_MIGRATION_LOCK_TTL', 2000)
      end

      def migration_table_name
        @migration_table_name ||= ENV.fetch('MYSQL_MIGRATION_TABLE', 'migration_script_history')
      end

      def migrations
        @migrations ||= MysqlFramework::Scripts::Base.descendants
      end

      def apply(script, client)
        MysqlFramework.logger.info { "[#{self.class}] - Applying script: #{script}." }

        script.apply(client)
        client.query(<<~SQL)
          INSERT INTO `#{migration_table_name}` (`identifier`, `timestamp`) VALUES ('#{script.identifier}', NOW())
        SQL
      end
    end
  end
end
