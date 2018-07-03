# frozen_string_literal: true

module MysqlFramework
  module Scripts
    class Manager
      def execute
        lock_manager.lock(self.class, 2000) do |locked|
          raise unless locked

          initialize_script_history

          last_executed_script = retrieve_last_executed_script

          mysql_connector.transaction do
            pending_scripts = calculate_pending_scripts(last_executed_script)
            MysqlFramework.logger.info { "[#{self.class}] - #{pending_scripts.length} pending data store scripts found." }

            pending_scripts.each { |script| apply(script) }
          end

          MysqlFramework.logger.info { "[#{self.class}] - Migration script execution complete." }
        end
      end

      def apply_by_tag(tags)
        lock_manager.lock(self.class, 2000) do |locked|
          raise unless locked

          initialize_script_history

          mysql_connector.transaction do
            pending_scripts = calculate_pending_scripts(0)
            MysqlFramework.logger.info { "[#{self.class}] - #{pending_scripts.length} pending data store scripts found." }

            pending_scripts.reject { |script| (script.tags & tags).empty? }.sort_by(&:identifier)
              .each { |script| apply(script) }
          end

          MysqlFramework.logger.info { "[#{self.class}] - Migration script execution complete." }
        end
      end

      def drop_all_tables
        drop_script_history
        all_tables.each { |table| drop_table(table) }
      end

      def retrieve_last_executed_script
        MysqlFramework.logger.info { "[#{self.class}] - Retrieving last executed script from history." }

        result = mysql_connector.query("SELECT `identifier` FROM #{migration_table_name}
                                        ORDER BY `identifier` DESC")

        if result.each.to_a.length.zero?
          0
        else
          Integer(result.first[:identifier])
        end
      end

      def initialize_script_history
        MysqlFramework.logger.info { "[#{self.class}] - Initializing script history." }

        mysql_connector.query("
          CREATE TABLE IF NOT EXISTS #{migration_table_name} (
            `identifier` CHAR(15) NOT NULL,
            `timestamp` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`),
            UNIQUE INDEX `identifier_UNIQUE` (`identifier` ASC)
          )
        ")
      end

      def calculate_pending_scripts(last_executed_script)
        MysqlFramework.logger.info { "[#{self.class}] - Calculating pending data store scripts." }

        MysqlFramework::Scripts::Base.descendants.map(&:new)
          .select { |script| script.identifier > last_executed_script }.sort_by(&:identifier)
      end

      def table_exists?(table_name)
        result = mysql_connector.query("SHOW TABLES LIKE '#{table_name}'")
        result.count == 1
      end

      def drop_script_history
        drop_table(migration_table_name)
      end

      def drop_table(table_name)
        mysql_connector.query("DROP TABLE IF EXISTS #{table_name}")
      end

      def all_tables
        self.class.all_tables
      end

      def self.all_tables
        @all_tables ||= []
      end

      private

      def mysql_connector
        @mysql_connector ||= MysqlFramework::Connector.new
      end

      def lock_manager
        @lock_manager ||= Redlock::Client.new([ENV.fetch('REDIS_URL')])
      end

      def database
        @database ||= ENV.fetch('MYSQL_DATABASE')
      end

      def migration_table_name
        return @migration_table_name if @migration_table_name

        @migration_table_name = "`#{database}`.`migration_script_history`"
      end

      def apply(script)
        MysqlFramework.logger.info { "[#{self.class}] - Applying script: #{script}." }

        script.apply
        mysql_connector.query("INSERT INTO #{migration_table_name}
                              (`identifier`, `timestamp`)
                              VALUES ('#{script.identifier}', NOW())")
      end
    end
  end
end
