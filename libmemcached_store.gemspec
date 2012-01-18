# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version"

Gem::Specification.new do |s|
  s.name        = "libmemcached_store"
  s.version     = LibmemcachedStore::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.summary     = "ActiveSupport cache store for the C-based libmemcached client"
  s.email       = "cocchi.c@gmail.com"
  s.homepage    = "http://github.com/ccocchi/libmemcached_store"
  s.description = %q{An ActiveSupport cache store that uses the C-based libmemcached client through
      Evan Weaver's Ruby/SWIG wrapper, memcached. libmemcached is fast, lightweight,
      and supports consistent hashing, non-blocking IO, and graceful server failover.}
  s.authors     = ["Christopher Cocchi-Perrier", "Ben Hutton", "Jeffrey Hardy"]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("memcached", ">= 0")
end

