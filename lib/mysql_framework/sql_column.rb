# frozen_string_literal: true

module MysqlFramework
  # This class is used to represent a sql column within a table
  class SqlColumn
    def initialize(table:, column:)
      @table = table
      @column = column
    end

    def to_s
      "`#{@table}`.`#{@column}`"
    end

    def to_sym
      @column.to_sym
    end

    # This method is called to create a equals (=) condition for this column.
    def eq(value)
      SqlCondition.new(column: to_s, comparison: '=', value: value)
    end

    # This method is called to create a not equal (<>) condition for this column.
    def not_eq(value)
      SqlCondition.new(column: to_s, comparison: '<>', value: value)
    end

    # This method is called to create a greater than (>) condition for this column.
    def gt(value)
      SqlCondition.new(column: to_s, comparison: '>', value: value)
    end

    # This method is called to create a greater than or equal (>=) condition for this column.
    def gte(value)
      SqlCondition.new(column: to_s, comparison: '>=', value: value)
    end

    # This method is called to create a less than (<) condition for this column.
    def lt(value)
      SqlCondition.new(column: to_s, comparison: '<', value: value)
    end

    # This method is called to create a less than or equal (<=) condition for this column.
    def lte(value)
      SqlCondition.new(column: to_s, comparison: '<=', value: value)
    end

    # This method is called to generate an alias statement for this column.
    def as(name)
      "#{self} as `#{name}`"
    end

    # This method is called to create a LIKE condition for this column.
    def like(value)
      SqlCondition.new(column: to_s, comparison: 'LIKE', value: value)
    end

    # This method is called to create a NOT LIKE condition for this column.
    def not_like(value)
      SqlCondition.new(column: to_s, comparison: 'NOT LIKE', value: value)
    end

    # This method is called to create an IN condition for this column.
    def in(value)
      SqlCondition.new(column: to_s, comparison: 'IN', value: value)
    end

    # This method is called to create a NOT IN condition for this column.
    def not_in(value)
      SqlCondition.new(column: to_s, comparison: 'NOT IN', value: value)
    end
  end
end
