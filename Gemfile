source 'https://rubygems.org'

gem 'rake'
gem 'rspec'
gem 'rails', '~> 3.2'
gem 'database_cleaner'
gem 'simplecov'

gem 'connection_pool'
gem 'redis', '~> 3.0.4'
gem 'mock_redis'

platform :mri_19, :mri_20 do
  gem 'cane'
end

platform :ruby do
  gem 'pg'
  gem 'mysql2'
  gem 'mysql'
  gem 'yajl-ruby'
  gem 'sqlite3'
  #gem 'perftools.rb'
end

platform :jruby do
  gem 'activerecord-jdbc-adapter', '>= 1.2.6'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbch2-adapter'
  gem 'jdbc-postgres'
  gem 'jruby-openssl'
end

gemspec
