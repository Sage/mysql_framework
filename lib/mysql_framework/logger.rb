# frozen_string_literal: true

require 'logger'

module MysqlFramework
  def self.logger
    @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end

  MysqlFramework.logger = Logger.new(STDOUT)
end
