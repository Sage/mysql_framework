# frozen_string_literal: true

module MysqlFramework
  module Support
    module Tables
      class DemoTable
        extend MysqlFramework::Scripts::Table

        NAME = 'demo'

        register_table NAME
      end
    end
  end
end
