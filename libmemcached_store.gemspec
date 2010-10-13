Gem::Specification.new do |s|
  s.name = %q{libmemcached_store}
  s.version = "0.3.0"

  s.authors = ["Shopify"]
  s.date = %q{2010-10-12}
  s.description = s.summary = %q{An ActiveSupport cache store that uses the C-based libmemcached client through
      Evan Weaver's Ruby/SWIG wrapper, memcached. libmemcached is fast, lightweight,
      and supports consistent hashing, non-blocking IO, and graceful server failover.}

  s.files = [ ".gitignore", "MIT-LICENSE", "README", "Rakefile", "libmemcached_store.gemspec" ]
  s.files += Dir.glob('lib/**/*')

  s.require_paths = ["lib"]
end

