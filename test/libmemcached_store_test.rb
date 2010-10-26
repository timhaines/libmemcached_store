$:.unshift File.expand_path('../../lib', __FILE__)
require 'test/unit'
require 'rubygems'
require 'active_support'
require 'memcached'
require 'mocha'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/object/duplicable'
require 'active_support/cache/libmemcached_store'

# Make it easier to get at the underlying cache options during testing.
class ActiveSupport::Cache::LibmemcachedStore < ActiveSupport::Cache::Store
  delegate :options, :to => '@cache'
end

class LibmemcachedStoreTest < Test::Unit::TestCase
  def setup
    @cache = ActiveSupport::Cache.lookup_store :libmemcached_store
  end

  def test_should_identify_cache_store
    assert_kind_of ActiveSupport::Cache::LibmemcachedStore, @cache
  end

  def test_should_set_server_addresses_to_localhost_if_none_are_given
    assert_equal %w(localhost), @cache.addresses
  end

  def test_should_set_custom_server_addresses
    store = ActiveSupport::Cache.lookup_store :libmemcached_store, 'localhost', '192.168.1.1'
    assert_equal %w(localhost 192.168.1.1), store.addresses
  end

  def test_should_enable_consistent_ketema_hashing_by_default
    assert_equal :consistent_ketama, @cache.options[:distribution]
  end

  def test_should_not_enable_non_blocking_io_by_default
    assert_nil @cache.options[:no_block]
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
