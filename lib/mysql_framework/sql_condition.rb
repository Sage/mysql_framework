# frozen_string_literal: true

module MysqlFramework
# This class is used to represent a Sql Condition for a column.
  class SqlCondition
    NIL_COMPARISONS = ['IS NULL', 'IS NOT NULL'].freeze

    # This method is called to get the value of this condition for prepared statements.
    attr_reader :value

    def initialize(column:, comparison:, value: nil)
      @column = column
      @comparison = comparison

      if nil_comparison?
        raise ArgumentError, "Cannot set value when comparison is #{comparison}" if value != nil
      else
        raise ArgumentError, "Comparison of #{comparison} requires value to be not nil" if value.nil?
      end

      @value = value
    end

    # This method is called to get the condition as a string for a sql prepared statement
    def to_s
      return "#{@column} #{@comparison.upcase}" if nil_comparison?

      "#{@column} #{@comparison} ?"
    end

    private

    def nil_comparison?
      NIL_COMPARISONS.include?(@comparison.upcase)
    end
  end
end
