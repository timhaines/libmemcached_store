require 'test_helper'
require 'memcached'
require 'active_support'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/object/duplicable'
require 'active_support/cache/libmemcached_store'

# Make it easier to get at the underlying cache options during testing.
class ActiveSupport::Cache::LibmemcachedStore
  delegate :options, :to => '@cache'
end

module CacheStoreBehavior
  def test_should_read_and_write_strings
    assert_equal true, @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_should_overwrite
    @cache.write('foo', 'bar')
    @cache.write('foo', 'baz')
    assert_equal 'baz', @cache.read('foo')
  end

  #Memcached connection dies if you try to read a key with length > 250
  def test_should_raise_an_exception_if_the_key_is_too_long
    lk = "a"*1000
    assert_raises(Memcached::NotStored) {
     @cache.read(lk)
    }
  end  

  def test_fetch_without_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:write).never
    assert_equal 'bar', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_cache_miss
    @cache.expects(:write).with('foo', 'baz', @cache.options)
    assert_equal 'baz', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_forced_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:read).never
    @cache.expects(:write).with('foo', 'bar', @cache.options.merge(:force => true))
    @cache.fetch('foo', :force => true) { 'bar' }
  end

  def test_fetch_with_cached_nil
    @cache.write('foo', nil)
    @cache.expects(:write).never
    assert_nil @cache.fetch('foo') { 'baz' }
  end

  def test_should_read_and_write_hash
    assert_equal true, @cache.write('foo', {:a => "b"})
    assert_equal({:a => "b"}, @cache.read('foo'))
  end

  def test_should_read_and_write_integer
    assert_equal true, @cache.write('foo', 1)
    assert_equal 1, @cache.read('foo')
  end

  def test_should_read_and_write_nil
    assert_equal true, @cache.write('foo', nil)
    assert_equal nil, @cache.read('foo')
  end

  def test_read_multi
    @cache.write('foo', 'bar')
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_read_and_write_compressed_small_data
    @cache.write('foo', 'bar', :compress => true)
    raw_value = @cache.send(:read_entry, 'foo', {}).raw_value
    assert_equal 'bar', @cache.read('foo')
    assert_equal 'bar', Marshal.load(raw_value)
  end

  def test_read_and_write_compressed_large_data
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 2)
    raw_value = @cache.send(:read_entry, 'foo', {}).raw_value
    assert_equal 'bar', @cache.read('foo')
    assert_equal 'bar', Marshal.load(Zlib::Inflate.inflate(raw_value))
  end

  def test_read_and_write_compressed_nil
    @cache.write('foo', nil, :compress => true)
    assert_nil @cache.read('foo')
  end

  def test_cache_key
    obj = Object.new
    def obj.cache_key
      :foo
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_param_as_cache_key
    obj = Object.new
    def obj.to_param
      "foo"
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_array_as_cache_key
    @cache.write([:fu, "foo"], "bar")
    assert_equal "bar", @cache.read("fu/foo")
  end

  def test_hash_as_cache_key
    @cache.write({:foo => 1, :fu => 2}, "bar")
    assert_equal "bar", @cache.read("foo=1/fu=2")
  end

  def test_keys_are_case_sensitive
    @cache.write("foo", "bar")
    assert_nil @cache.read("FOO")
  end

  def test_exist
    @cache.write('foo', 'bar')
    assert_equal true, @cache.exist?('foo')
    assert_equal false, @cache.exist?('bar')
  end

  def test_nil_exist
    @cache.write('foo', nil)
    assert_equal true, @cache.exist?('foo')
  end

  def test_delete
    @cache.write('foo', 'bar')
    assert @cache.exist?('foo')
    assert_equal true, @cache.delete('foo')
    assert !@cache.exist?('foo')
  end

  def test_store_objects_should_be_immutable
    @cache.write('foo', 'bar')
    @cache.read('foo').gsub!(/.*/, 'baz')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_original_store_objects_should_not_be_immutable
    bar = 'bar'
    @cache.write('foo', bar)
    assert_equal 'baz', bar.gsub!(/r/, 'z')
  end

  def test_expires_in
    time = Time.local(2008, 4, 24)
    Time.stubs(:now).returns(time)

    @cache.write('foo', 'bar', :expires_in => 45)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 30)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 61)
    assert_nil @cache.read('foo')
  end

  def test_expires_in_as_activesupport_duration
    time = Time.local(2012, 02, 03)
    Time.stubs(:now).returns(time)

    @cache.write('foo', 'bar', :expires_in => 1.minute)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 30)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 61)
    assert_nil @cache.read('foo')
  end

  def test_expires_in_as_float
    time = Time.local(2012, 02, 03)
    Time.stubs(:now).returns(time)

    @cache.write('foo', 'bar', :expires_in => 60.0)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 30)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 61)
    assert_nil @cache.read('foo')
  end

  def test_race_condition_protection
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 61)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      assert_equal 'bar', @cache.read('foo')
      "baz"
    end
    assert_equal "baz", result
  end

  def test_race_condition_protection_is_limited
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 71)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      assert_equal nil, @cache.read('foo')
      "baz"
    end
    assert_equal "baz", result
  end

  def test_race_condition_protection_is_safe
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 61)
    begin
      @cache.fetch('foo', :race_condition_ttl => 10) do
        assert_equal 'bar', @cache.read('foo')
        raise ArgumentError.new
      end
    rescue ArgumentError
    end
    assert_equal "bar", @cache.read('foo')
    Time.stubs(:now).returns(time + 71)
    assert_nil @cache.read('foo')
  end

  def test_crazy_key_characters
    crazy_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert_equal true, @cache.write(crazy_key, "1", :raw => true)
    assert_equal "1", @cache.read(crazy_key)
    assert_equal "1", @cache.fetch(crazy_key)
    assert_equal true, @cache.delete(crazy_key)
    assert_equal "2", @cache.fetch(crazy_key, :raw => true) { "2" }
    assert_equal 3, @cache.increment(crazy_key)
    assert_equal 2, @cache.decrement(crazy_key)
  end

  # def test_really_long_keys
    # key = ""
    # 1000.times{key << "x"}
    # assert_equal true, @cache.write(key, "bar")
    # assert_equal "bar", @cache.read(key)
    # assert_equal "bar", @cache.fetch(key)
    # assert_nil @cache.read("#{key}x")
    # assert_equal({key => "bar"}, @cache.read_multi(key))
    # assert_equal true, @cache.delete(key)
  # end
end

module CacheIncrementDecrementBehavior
  def test_increment
    @cache.write('foo', 1, :raw => true)
    assert_equal 1, @cache.read('foo').to_i
    assert_equal 2, @cache.increment('foo')
    assert_equal 2, @cache.read('foo').to_i
    assert_equal 3, @cache.increment('foo')
    assert_equal 3, @cache.read('foo').to_i
  end

  def test_decrement
    @cache.write('foo', 3, :raw => true)
    assert_equal 3, @cache.read('foo').to_i
    assert_equal 2, @cache.decrement('foo')
    assert_equal 2, @cache.read('foo').to_i
    assert_equal 1, @cache.decrement('foo')
    assert_equal 1, @cache.read('foo').to_i
  end
end

class LibmemcachedStoreTest < MiniTest::Unit::TestCase
  include CacheStoreBehavior
  include CacheIncrementDecrementBehavior

  def setup
    @cache = ActiveSupport::Cache.lookup_store(:libmemcached_store, :expires_in => 60)
    @cache.clear
    @cache.silence!
  end

  def test_should_identify_cache_store
    assert_kind_of ActiveSupport::Cache::LibmemcachedStore, @cache
  end

  def test_should_set_server_addresses_to_nil_if_none_are_given
    assert_equal [], @cache.addresses
  end

  def test_should_set_custom_server_addresses
    store = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost', '192.168.1.1'
    assert_equal %w(localhost 192.168.1.1), store.addresses
  end

  def test_should_enable_consistent_ketema_hashing_by_default
    assert_equal :consistent_ketama, @cache.options[:distribution]
  end

  def test_should_not_enable_non_blocking_io_by_default
    assert_equal false, @cache.options[:no_block]
  end

  def test_should_not_enable_server_failover_by_default
    assert_nil @cache.options[:failover]
  end

  def test_should_allow_configuration_of_custom_options
    options = {
      :tcp_nodelay => true,
      :distribution => :modula
    }

    store = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost', options

    assert_equal :modula, store.options[:distribution]
    assert_equal true, store.options[:tcp_nodelay]
  end
end
