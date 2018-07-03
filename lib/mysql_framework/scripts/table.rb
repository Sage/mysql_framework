# frozen_string_literal: true

module MysqlFramework
  module Scripts
    module Table
      def register_table(name)
        MysqlFramework::Scripts::Manager.all_tables << name
      end
    end
  end
end
