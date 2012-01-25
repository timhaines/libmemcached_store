require 'memcached'
require 'rack/session/abstract/id'

module ActionDispatch
  module Session
    class LibmemcachedStore < AbstractStore

      DEFAULT_OPTIONS = Rack::Session::Abstract::ID::DEFAULT_OPTIONS.merge(:prefix_key => 'rack:session', :memcache_server => 'localhost:11211')

      def initialize(app, options = {})
        options[:expire_after] ||= options[:expires]
        super
        @mutex = Mutex.new
        @pool = options[:cache] || Memcached.new(@default_options[:memcache_server], @default_options)
      end

      private

      def generate_sid
        loop do
          sid = super
          begin
            @pool.get(sid)
          rescue Memcached::NotFound
            break sid
          end
        end
      end

      def get_session(env, sid)
        sid ||= generate_sid
        session = with_lock(env, {}) do
          begin
            @pool.get(sid)
          rescue Memcached::NotFound
            {}
          end
        end
        [sid, session]
      end

      def set_session(env, session_id, new_session, options = {})
        expiry  = options[:expire_after]
        expiry = expiry.nil? ? 0 : expiry + 1

        with_lock(env, false) do
          @pool.set(session_id, new_session, expiry)
          session_id
        end
      end

      def destroy_session(env, session_id, options = {})
        with_lock(env, nil) do
          @pool.delete(session_id)
          generate_sid unless options[:drop]
        end
      end

      def with_lock(env, default)
        @mutex.lock if env['rack.multithread']
        yield
      rescue Memcached::Error => e
        logger.error e.error
        default
      ensure
        @mutex.unlock if @mutex.locked?
      end

    end
  end
end
