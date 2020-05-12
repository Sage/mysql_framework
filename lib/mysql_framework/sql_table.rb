# frozen_string_literal: true

module MysqlFramework
  # This class is used to represent a sql table
  class SqlTable
    def initialize(name)
      @name = name
      @column_objects = {}
    end

    # This method is called to get a sql column for this table
    def [](column)
      return @column_objects[column.to_sym] if @column_objects[column.to_sym]
      @column_objects[column.to_sym] = SqlColumn.new(table: @name, column: column)
    end

    def to_s
      "`#{@name}`"
    end

    def to_sym
      @name.to_sym
    end
  end
end
