require 'memcached'

class ActiveSupport::Cache::Entry
  # In 3.0 all values returned from Rails.cache.read are frozen.
  # This makes sense for an in-memory store storing object references,
  # but for a marshalled store we should be able to modify things.
  # Starting with 3.2, values are not frozen anymore.
  def value_with_dup
    result = value_without_dup
    result.frozen? && result.duplicable? ? result.dup : result
  end
  alias_method_chain :value, :dup
end

module ActiveSupport
  module Cache
    class LibmemcachedStore < Store
      attr_reader :addresses

      DEFAULT_OPTIONS = {}
      # {
      #   :distribution => :consistent_ketama,
      #   :binary_protocol => true
      # }

      def initialize(*addresses)
        addresses.flatten!
        @options = addresses.extract_options!
        @addresses = addresses
        @cache = Memcached.new(@addresses, @options.reverse_merge(DEFAULT_OPTIONS))
      end

      def increment(key, amount = 1, options = nil)
        log 'incrementing', key, amount
        @cache.incr(key, amount)
      rescue Memcached::Error
        raise
      end

      def decrement(key, amount = 1, options = nil)
        log 'decrementing', key, amount
        @cache.decr(key, amount)
      rescue Memcached::Error
        raise
      end

      def clear
        @cache.flush
      end

      def stats
        @cache.stats
      end

      def read_multi(*names)
        options = names.extract_options!
        options = merged_options(options)
        instrument(:read_multi, names) do
          @cache.get(names)
        end  
      rescue Memcached::Error => e
        log_error(e)
        raise
      end

      def read(name, options={})
        instrument(:read, name, options) do |payload|
          value = @cache.get(name)
          payload[:hit] = !!value if payload
          value
        end    
      rescue Memcached::NotFound
        nil      
      rescue Memcached::Error => e
        log_error(e)
        raise
      end

      def exists?(name, options={})
        !!@cache.read(name)
      rescue Memcached::Error => e
        log_error(e)
        raise
      end
      
      def write(name, value, options={})
        method = (options && options[:unless_exist]) ? :add : :set                
        instrument(:write, name, options) do |payload|
          @cache.send(method, name, value, expires_in(options), marshal?(options))
        end
        true
      rescue Memcached::Error => e
        log_error(e)
        raise
      end

      def fetch(name, options={})
        if block_given?
          value = nil
          unless options[:force]
            value = instrument(:read, name, options) do |payload|
              payload[:super_operation] = :fetch if payload
              read(name, options)
            end
          end

          if value
            instrument(:fetch_hit, name, options) { |payload| }
            value
          else
            result = instrument(:generate, name, options) do |payload|
              yield
            end
            write(name, result, options)
            result
          end
        else
          read(name, options)
        end
      rescue Memcached::Error => e
        log_error(e)
        raise
      end

      def delete(name, options={})
        @cache.delete(name)
        true
      rescue Memcached::NotFound
        false   
      rescue Memcached::Error => e
        log_error(e)
        raise
      end  


      protected

      def read_entry(key, options = nil)
        deserialize_entry(@cache.get(key, false)) 
      rescue Memcached::NotFound
        nil
      rescue Memcached::Error => e
        log_error(e)
        raise
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
        raise
      end

      def delete_entry(key, options = nil)
        @cache.delete(key)
        true
      rescue Memcached::Error => e
        log_error(e)
        raise
      end

      private
      def deserialize_entry(raw_value)
        if raw_value
          entry = Marshal.load(raw_value) rescue raw_value
          entry.is_a?(Entry) ? entry : Entry.new(entry)
        else
          nil
        end
      end

      def expires_in(options)
        (options || {})[:expires_in].to_i
      end

      def marshal?(options)
        !(options || {})[:raw]
      end

      def log_error(exception)
        return unless logger && logger.error?
        logger.error "MemcachedError (#{exception.inspect}): #{exception.message}"
      end
    end
  end
end
