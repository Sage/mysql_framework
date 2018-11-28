# frozen_string_literal: true

RSpec.describe MysqlFramework::Scripts::LockManager do
  describe '#fetch_client' do
    context 'when the connection pool is empty' do
      it 'returns a new redlock client' do
        expect(subject.fetch_client).to be_a(Redlock::Client)
      end
    end

    context 'when the connection pool is NOT empty' do
      let(:client) { Redlock::Client.new([ENV['REDIS_URL']]) }

      before do
        pool = subject.instance_variable_get(:@pool)
        pool.push(client)
      end

      it 'returns a redlock client from the pool' do
        expect(subject.fetch_client).to eq client
      end
    end
  end

  describe '#with_lock' do
    let(:key) { SecureRandom.uuid }

    context 'When key is NOT locked' do
      context 'when a block is specified' do
        let(:foo) { {} }

        it 'requests a lock, executes the block and releases the lock' do
          subject.with_lock(key: key, ttl: 1_000) do
            foo[:bar] = 'abc'
            sleep(0.1)
          end

          expect(foo[:bar]).to eq 'abc'
          expect(subject.request_lock(key: key)).not_to be_nil
        end
      end
    end
  end

  describe '#request_lock' do
    let(:key) { SecureRandom.uuid }

    context 'When key is NOT locked' do
      it 'returns a lock' do
        expect(subject.request_lock(key: key)).not_to be_nil
      end
    end

    context 'When key is locked' do
      before { subject.request_lock(key: key, ttl: 3_000) }

      context 'but the lock expires within the wait ttl' do
        it 'returns a lock' do
          expect(subject.request_lock(key: key, max_attempts: 5, retry_delay: 1)).not_to be_nil
        end
      end

      it 'raises a KeyLockError' do
        expect { subject.request_lock(key: key, max_attempts: 1, retry_delay: 1) }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#release_lock' do
    let(:key) { SecureRandom.uuid }
    let(:lock) { subject.request_lock(key: key) }

    it 'releases the lock' do
      expect { subject.release_lock(key: key, lock: lock) }.not_to raise_error
      expect(subject.request_lock(key: key, max_attempts: 1, retry_delay: 1)).not_to be_nil
    end

    context 'when lock is nil' do
      it 'does not error' do
        expect { subject.release_lock(key: key, lock: nil) }.not_to raise_error
      end
    end
  end
end
