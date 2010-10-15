require 'memcached'

class Memcached
  # The latest version of memcached (0.11) doesn't support hostnames with dashes
  # in their names, so we overwrite it here to be more lenient.
  def set_servers(servers)
    [*servers].each_with_index do |server, index|
      host, port = server.split(":")
      Lib.memcached_server_add(@struct, host, port.to_i)
    end
  end
end

class ActiveSupport::Cache::Entry
  # In 3.0 all values returned from Rails.cache.read are frozen.
  # This makes sense for an in-memory store storing object references,
  # but for a marshalled store we should be able to modify things.
  def value_with_dup
    result = value_without_dup
    result.duplicable? ? result.dup : result
  end
  alias_method_chain :value, :dup
end

module ActiveSupport
  module Cache
    class LibmemcachedStore < Store
      attr_reader :addresses, :options

      DEFAULT_OPTIONS = {
        :distribution => :consistent,
        :no_block => true,
        :failover => true
      }

      def initialize(*addresses)
        addresses.flatten!
        @options = addresses.extract_options!
        addresses = %w(localhost) if addresses.empty?

        @addresses = addresses
        @cache = Memcached.new(@addresses, @options.reverse_merge(DEFAULT_OPTIONS))
      end

      def increment(key, amount=1)
        log 'incrementing', key, amount
        @cache.incr(key, amount)
      rescue Memcached::Error
        nil
      end

      def decrement(key, amount=1)
        log 'decrementing', key, amount
        @cache.decr(key, amount)
      rescue Memcached::Error
        nil
      end

      def clear
        @cache.flush
      end

      def stats
        @cache.stats
      end

      protected

      def read_entry(key, options = nil)
        entry = @cache.get(key, marshal?(options))
        entry.is_a?(Entry) ? entry : Entry.new(entry)
      rescue Memcached::NotFound
        nil
      rescue Memcached::Error => e
        log_error(e)
        nil
      end

      # Set the key to the given value. Pass :unless_exist => true if you want to
      # skip setting a key that already exists.
      def write_entry(key, entry, options = nil)
        method = (options && options[:unless_exist]) ? :add : :set
        value = options[:raw] ? entry.value.to_s : entry

        @cache.send(method, key, value, expires_in(options), marshal?(options))
        true
      rescue Memcached::Error => e
        log_error(e)
        false
      end

      def delete_entry(key, options = nil)
        @cache.delete(key)
        true
      rescue Memcached::Error => e
        log_error(e)
        false
      end

      private

      def expires_in(options)
        (options || {})[:expires_in] || 0
      end

      def marshal?(options)
        !(options || {})[:raw]
      end

      def log_error(exception)
        logger.error "MemcachedError (#{exception.inspect}): #{exception.message}" if logger && !@logger_off
      end
    end
  end
end
