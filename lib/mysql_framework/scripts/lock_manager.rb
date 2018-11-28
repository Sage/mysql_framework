# frozen_string_literal: true

require 'redlock'

module MysqlFramework
  module Scripts
    class LockManager
      def initialize
        @pool = Queue.new
      end

      def fetch_client
        @pool.pop(true)
      rescue StandardError
        # By not letting redlock retry we will rely on the retry that happens in this class
        Redlock::Client.new([redis_url], retry_jitter: retry_jitter, retry_count: 1, retry_delay: 0)
      end

      def with
        client = fetch_client
        yield client
      ensure
        @pool.push(client)
      end

      # This method is called to request a lock (Default 5 minutes)
      def request_lock(key:, ttl: default_ttl, max_attempts: default_max_retries, retry_delay: default_retry_delay)
        MysqlFramework.logger.info { "[#{self.class}] - Requesting lock: #{key}." }

        lock = false
        count = 0

        loop do
          # request a lock
          lock = with { |client| client.lock(key, ttl) }

          # if lock was received break out of the loop
          break if lock != false && !lock.nil?

          # lock was not received so increment request count
          count += 1

          MysqlFramework.logger.debug do
            "[#{self.class}] - Key is currently locked, waiting for lock: #{key} | Wait count: #{count}."
          end

          # check if lock requests have exceeded max request attempts
          raise "Resource is already locked. Lock key: #{key}. Max attempt exceeded." if count == max_attempts

          # sleep and try requesting the lock again
          sleep(retry_delay)
        end

        lock
      end

      # This method is called to release a lock
      def release_lock(key:, lock:)
        return if lock.nil?

        MysqlFramework.logger.info { "[#{self.class}] - Releasing lock: #{key}." }

        with { |client| client.unlock(lock) }
      end

      def with_lock(key:, ttl: default_ttl, max_attempts: default_max_retries, retry_delay: default_retry_delay)
        raise 'Block must be specified.' unless block_given?

        begin
          lock = request_lock(key: key, ttl: ttl, max_attempts: max_attempts, retry_delay: retry_delay)
          yield
        ensure
          release_lock(key: key, lock: lock)
        end
      end

      private

      def redis_url
        ENV['REDIS_URL']
      end

      def default_ttl
        @default_ttl ||= Integer(ENV.fetch('MYSQL_MIGRATION_LOCK_TTL', 2000))
      end

      def default_max_retries
        @default_max_retries ||= Integer(ENV.fetch('MYSQL_MIGRATION_LOCK_MAX_ATTEMPTS', 300))
      end

      def default_retry_delay
        @default_retry_delay ||= Float(ENV.fetch('MYSQL_MIGRATION_LOCK_RETRY_DELAY_S', 1.0))
      end

      def retry_jitter
        @retry_jitter ||= Integer(ENV.fetch('MYSQL_MIGRATION_LOCK_JITTER_MS', 50))
      end
    end
  end
end
