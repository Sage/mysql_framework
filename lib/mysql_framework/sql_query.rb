# frozen_string_literal: true

module MysqlFramework
  # This class is used to represent and build a sql query
  class SqlQuery
    # This method is called to get any params required to execute this query as a prepared statement.
    attr_reader :params

    def initialize
      @sql = ''
      @params = []
      @lock = nil
    end

    # This method is called to access the sql string for this query.
    def sql
      (@sql + @lock.to_s + @dup_query.to_s).strip
    end

    # This method is called to start a select query
    def select(*columns)
      @sql = "SELECT #{columns.join(', ')}"

      self
    end

    # This method is called to start a delete query
    def delete
      @sql = 'DELETE'

      self
    end

    # This method is called to start an update query
    def update(table, partition = nil)
      @sql = "UPDATE #{table}"
      @sql += " PARTITION (p#{partition})" unless partition.nil?

      self
    end

    # This method is called to start an insert query
    def insert(table, partition = nil)
      @sql += "INSERT INTO #{table}"
      @sql += " PARTITION (p#{partition})" unless partition.nil?

      self
    end

    # This method is called to specify the columns to insert into.
    def into(*columns)
      @sql += " (#{columns.join(', ')})"

      self
    end

    # This method is called to specify the values to insert.
    def values(*values)
      @sql += " VALUES (#{values.map { '?' }.join(', ')})"

      values.each { |value| @params << value }

      self
    end

    # This method is called to specify the values to bulk insert.
    def bulk_values(bulk_values)
      @sql += ' VALUES'

      bulk_values.each do |values|
        @sql += "(#{values.map { '?' }.join(', ')}),"
        @params += values
      end

      @sql = @sql.chomp(',')

      self
    end

    # This method is called to specify the columns to bulk upsert.
    def bulk_upsert(columns)
      @sql += 'ON DUPLICATE KEY UPDATE '

      columns.each do |column|
        @sql += "#{column} = VALUES(#{column}), "
      end

      @sql = @sql.chomp(', ')

      self
    end

    # This method is called to specify the columns to update.
    def set(values)
      @sql += ' SET '

      values.each do |key, param|
        @sql += "`#{key}` = ?, "
        @params << param
      end

      @sql = @sql.chomp(', ')

      self
    end

    def increment(values)
      @sql += @sql.include?('SET') ? ', ' : ' SET '

      values.each { |key, by| @sql += "`#{key}` = `#{key}` + #{by}, " }

      @sql = @sql.chomp(', ')

      self
    end

    def decrement(values)
      @sql += @sql.include?('SET') ? ', ' : ' SET '

      values.each { |key, by| @sql += "`#{key}` = `#{key}` - #{by}, " }

      @sql = @sql.chomp(', ')

      self
    end

    # This method is called to specify the table/partition a select/delete query is for.
    def from(table, partition = nil)
      @sql += " FROM #{table}"
      @sql += " PARTITION (p#{partition})" unless partition.nil?

      self
    end

    # This method is called to specify a where clause for a query.
    def where(*conditions)
      @sql += ' WHERE' unless @sql.include?('WHERE')
      @sql += " (#{conditions.join(' AND ')}) "

      conditions.each do |condition|
        if condition.value.is_a?(Enumerable)
          @params.concat(condition.value)
        else
          @params << condition.value
        end
      end

      self
    end

    # This method is called to add an `and` keyword to a query to provide additional where clauses.
    def and
      @sql += 'AND'

      self
    end

    # This method is called to add an `or` keyword to a query to provide alternate where clauses.
    def or
      @sql += 'OR'

      self
    end

    # This method is called to add an `order by` statement to a query
    def order(*columns)
      @sql += " ORDER BY #{columns.join(', ')}"

      self
    end

    # This method is called to add an `order by ... desc` statement to a query
    def order_desc(*columns)
      order(*columns)

      @sql += ' DESC'

      self
    end

    # This method is called to add a limit to a query
    def limit(count)
      @sql += " LIMIT #{count}"

      self
    end

    # This method is called to add an offset to a query
    def offset(offset)
      raise 'A limit clause must be supplied to use an offset' unless @sql.include?('LIMIT')

      @sql += " OFFSET #{offset}"

      self
    end

    # This method is called to add a join statement to a query.
    def join(table, type: nil)
      @sql += " #{type.upcase}" unless type.nil?
      @sql += " JOIN #{table}"

      self
    end

    # This method is called to add the `on` detail to a join statement.
    def on(column_1, column_2)
      @sql += " ON #{column_1} = #{column_2}"

      self
    end

    # This method is called to add a `group by` statement to a query
    def group_by(*columns)
      @sql += " GROUP BY #{columns.join(', ')}"

      self
    end

    # This method is called to specify a having clause for a query.
    def having(*conditions)
      @sql += ' HAVING' unless @sql.include?('HAVING')
      @sql += " (#{conditions.join(' AND ')}) "

      conditions.each { |condition| @params << condition.value }

      self
    end

    # This method allows you to add a pessimistic lock to the record.
    # The default lock is `FOR UPDATE`
    # If you require any custom lock, e.g. FOR SHARE, just pass that in as the condition
    # query.lock('FOR SHARE')
    def lock(condition = nil)
      raise 'This must be a SELECT query' unless @sql.start_with?('SELECT')

      @lock = ' ' + (condition || 'FOR UPDATE')
      self
    end

    # For insert queries if you need to handle that a primary key already exists and automatically do an update instead.
    # If you do not pass in a hash specifying a column name and custom value for it, we will assume that each column
    # specified in the update_columns will be updated by the value used to INSERT.
    # The #update_values parameter is useful when the update requires a
    # different value on UPDATE than on INSERT on some or all the columns.
    # e.g.
    # query.insert('users')
    # .into('id', first_name', 'login_count')
    # .values(1, 'Bob', 1)
    # .duplicate_update(
    #   update_columns: [
    #     first_name,
    #     login_count
    #   ],
    #   update_values: {login_count: 'login_count + 5'})
    # This would first create a record like => `1, 'Bob', 1`.
    # The second time it would update it to => `1, 'Bob', 6`
    def duplicate_update(update_columns:, update_values: {})
      raise 'This must be an INSERT query' unless @sql.start_with?('INSERT')

      duplicates = []
      update_columns.each do |column|
        if update_values[column.to_sym]
          # custom value if doing an update
          updated_value = "#{column} = #{update_values[column.to_sym]}"
        else
          # value comes from what the INSERT intended
          updated_value = "#{column} = VALUES (#{column})"
        end
        duplicates << updated_value
      end
      @dup_query = " ON DUPLICATE KEY UPDATE #{duplicates.join(',')}"

      self
    end
  end
end
