module ActiveSupport
  module Cache
    class CompressedLibmemcachedStore < LibmemcachedStore
      def read(name, options = {})
        if value = super(name, options)
          Marshal.load(ActiveSupport::Gzip.decompress(value))
        end
      end

      def write(name, value, options = {})
        super(name, ActiveSupport::Gzip.compress(Marshal.dump(value)), options)
      end
    end
  end
end
