# frozen_string_literal: true

module MysqlFramework
  # This class is used to represent and build a sql query
  class SqlQuery
    # This method is called to get any params required to execute this query as a prepared statement.
    attr_reader :params

    def initialize
      @sql = ''
      @params = []
    end

    # This method is called to access the sql string for this query.
    def sql
      @sql.strip
    end

    # This method is called to start a select query
    def select(*columns)
      @sql = "select #{columns.join(',')}"
      self
    end

    # This method is called to start a delete query
    def delete
      @sql = 'delete'
      self
    end

    # This method is called to start an update query
    def update(table, partition = nil)
      @sql = "update #{table}"
      @sql += " partition(p#{partition})" unless partition.nil?
      self
    end

    # This method is called to start an insert query
    def insert(table, partition = nil)
      @sql += "insert into #{table}"
      @sql += " partition(p#{partition})" unless partition.nil?
      self
    end

    # This method is called to specify the columns to insert into.
    def into(*columns)
      @sql += " (#{columns.join(',')})"
      self
    end

    # This method is called to specify the values to insert.
    def values(*values)
      @sql += " values (#{values.map { |_v| '?' }.join(',')})"
      values.each do |v|
        @params << v
      end
      self
    end

    # This method is called to specify the columns to update.
    def set(values)
      @sql += ' set '
      values.each do |k, p|
        @sql += "`#{k}` = ?, "
        @params << p
      end
      @sql = @sql[0...-2]
      self
    end

    # This method is called to specify the table/partition a select/delete query is for.
    def from(table, partition = nil)
      @sql += " from #{table}"
      @sql += " partition(p#{partition})" unless partition.nil?
      self
    end

    # This method is called to specify a where clause for a query.
    def where(*conditions)
      @sql += ' where' unless @sql.include?('where')
      @sql += " (#{conditions.join(' and ')}) "
      conditions.each do |c|
        @params << c.value
      end
      self
    end

    # This method is called to add an `and` keyword to a query to provide additional where clauses.
    def and
      @sql += 'and'
      self
    end

    # This method is called to add an `or` keyword to a query to provide alternate where clauses.
    def or
      @sql += 'or'
      self
    end

    # This method is called to add an `order by` statement to a query
    def order(*columns)
      @sql += " order by #{columns.join(',')}"
      self
    end

    # This method is called to add an `order by ... desc` statement to a query
    def order_desc(*columns)
      order(*columns)
      @sql += ' desc'
      self
    end

    # This method is called to add a limit to a query
    def limit(count)
      @sql += " limit #{count}"
      self
    end

    # This method is called to add a join statement to a query.
    def join(table)
      @sql += " join #{table}"
      self
    end

    # This method is called to add the `on` detail to a join statement.
    def on(column_1, column_2)
      @sql += " on #{column_1} = #{column_2}"
      self
    end

    # This method is called to add a `group by` statement to a query
    def group_by(*columns)
      @sql += " group by #{columns.join(',')}"
      self
    end
  end
end
