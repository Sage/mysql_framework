# frozen_string_literal: true

module MysqlFramework
# This class is used to represent a Sql Condition for a column.
  class SqlCondition
    NIL_COMPARISONS = ['IS NULL', 'IS NOT NULL'].freeze

    # This method is called to get the value of this condition for prepared statements.
    attr_reader :value

    # Creates a new SqlCondition using the given parameters.
    #
    # @raise ArgumentError if comparison is 'IS NULL' and value is not nil
    # @raise ArgumentError if comparison is 'IS NOT NULL' and value is not nil
    # @raise ArgumentError if comparison is neither 'IS NULL' or 'IS NOT NULL' and value is nil
    #
    # @param column [String] - the name of the column to use in the comparison
    # @param comparison [String] - the MySQL comparison operator to use
    # @param value [Object] - the value to use in the comparison (default nil)
    def initialize(column:, comparison:, value: nil)
      @column = column
      @comparison = comparison

      validate(value)
      @value = value
    end

    # This method is called to get the condition as a string for a sql prepared statement
    #
    # @return [String]
    def to_s
      return "#{@column} #{@comparison.upcase}" if nil_comparison?

      "#{@column} #{@comparison} ?"
    end

    private

    def nil_comparison?
      NIL_COMPARISONS.include?(@comparison.upcase)
    end

    def validate(value)
      raise ArgumentError, "Cannot set value when comparison is #{@comparison}" if invalid_null_condition?(value)
      raise ArgumentError, "Comparison of #{@comparison} requires value to be not nil" if invalid_nil_value?(value)
    end

    def invalid_null_condition?(value)
      nil_comparison? && value != nil
    end

    def invalid_nil_value?(value)
      nil_comparison? == false && value.nil?
    end
  end
end
