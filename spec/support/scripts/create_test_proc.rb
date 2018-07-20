# frozen_string_literal: true

module MysqlFramework
  module Support
    module Scripts
      class CreateTestProc < MysqlFramework::Scripts::Base
        def initialize
          @identifier = 201807031200 # 12:90 03/07/2018
        end

        PROC_FILE = 'spec/support/procedure.sql'

        def apply(client)
          update_procedure(client, 'test_procedure', PROC_FILE)
        end

        def rollback(_client)
          raise 'Rollback not supported in test.'
        end

        def tags
          [table_name, 'TestProc']
        end

        private

        def table_name
          MysqlFramework::Support::Tables::TestTable::NAME
        end
      end
    end
  end
end
