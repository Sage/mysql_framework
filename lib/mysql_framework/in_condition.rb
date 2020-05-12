# frozen_string_literal: true

module MysqlFramework
# This class is used to represent a Sql IN Condition for a column.
  class InCondition < SqlCondition
    # This method is called to get the condition as a string for a sql prepared statement
    def to_s
      params = value.map { |_| '?' }
      "#{@column} #{@comparison} (#{params.join(', ')})"
    end
  end
end
