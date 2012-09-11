ENV['RAILS_ENV'] = 'test'

begin
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
  end
rescue LoadError
  puts "Coverage disabled."
end

require 'active_record'

jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'

$adapter = ENV['ADAPTER'] ||
  if jruby
    'jdbcpostgresql'
  else
    'postgresql'
  end

DATABASE_CONFIG = YAML.load_file(File.expand_path("../config/database.yml", File.dirname(__FILE__)))
db_config = DATABASE_CONFIG[$adapter]

if db_config.nil?
  puts "No such adapter '#{$adapter}'. Valid adapters are #{DATABASE_CONFIG.keys.join(', ')}."
  exit 1
end

if jruby
  if ENV['TRAVIS']
    db_config['username'] = 'postgres'
  else
    require 'etc'
    db_config['username'] = Etc.getlogin
  end
end

puts "Using #{$adapter} adapter."

ActiveRecord::Base.establish_connection(db_config)

require 'generators/templates/create_rapns_notifications'
require 'generators/templates/create_rapns_feedback'
require 'generators/templates/add_alert_is_json_to_rapns_notifications'
require 'generators/templates/add_app_to_rapns'
require 'generators/templates/create_rapns_apps'

[CreateRapnsNotifications, CreateRapnsFeedback,
 AddAlertIsJsonToRapnsNotifications, AddAppToRapns, CreateRapnsApps].each do |migration|
  migration.down rescue ActiveRecord::StatementInvalid
  migration.up
end

require 'bundler'
Bundler.require(:default)

require 'shoulda'
require 'database_cleaner'

DatabaseCleaner.strategy = :truncation

require 'rapns'
require 'rapns/daemon'

#require 'perftools'

RSpec.configure do |config|
  # config.before :suite do
  #   PerfTools::CpuProfiler.start('/tmp/rapns_profile')
  # end
  # config.after :suite do
  #   PerfTools::CpuProfiler.stop
  # end

  config.before(:each) { DatabaseCleaner.clean }
end
