# frozen_string_literal: true

require 'logger'

module MysqlFramework
  def self.logger
    return @@logger
  end

  def self.set_logger(logger)
    @@logger = logger
  end

  MysqlFramework.set_logger(Logger.new(STDOUT))
end
