require 'rubygems'
require 'bundler/setup'
# require 'appraisal'

require 'rake'
require 'rake/testtask'
require 'rdoc/task'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
  t.verbose = true
end

desc 'Generate documentation for the libmemcached_store plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'LibmemcachedStore'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
