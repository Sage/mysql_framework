# frozen_string_literal: true

module MysqlFramework
  module Support
    module Tables
      class TestTable
        extend MysqlFramework::Scripts::Table

        NAME = 'test'

        register_table NAME
      end
    end
  end
end
