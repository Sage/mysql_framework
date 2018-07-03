# frozen_string_literal: true

module MysqlFramework
# This class is used to represent a Sql Condition for a column.
  class SqlCondition
    # This method is called to get the value of this condition for prepared statements.
    attr_reader :value

    def initialize(column:, comparison:, value:)
      @column = column
      @comparison = comparison
      @value = value
    end

    # This method is called to get the condition as a string for a sql prepared statement
    def to_s
      "#{@column} #{@comparison} ?"
    end
  end
end
