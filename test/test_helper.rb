ENV["RAILS_ENV"] = "test"
require 'pathname'
this_dir = Pathname.new File.dirname(__FILE__)
$LOAD_PATH << this_dir.join("../lib")

gem "rails", "3.0.0.beta"
require "rails"
require "rails/test_help"
require "active_record/fixtures"
require "active_support/test_case"
require 'active_support/core_ext/object/returning'

require "delorean"

require "ar-extensions"
require "logger"

require "ruby-debug"

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  self.use_transactional_fixtures = true
  
  class << self
    def describe(description, toplevel=nil, &blk)
      text = toplevel ? description : "#{name} #{description}"
      klass = Class.new(self)
      klass.class_eval <<-RUBY_EVAL
        def self.name
          "#{text}"
        end
      RUBY_EVAL
      klass.instance_eval &blk
    end
    alias_method :context, :describe
    
    def let(name, &blk)
      values = {}
      define_method(name) do
        return values[name] if values.has_key?(name)
        values[name] = instance_eval(&blk)
      end
    end
    
    def it(description, &blk)
      define_method("test: #{name} #{description}", &blk)
    end
  end
  
end

def describe(description, &blk)
  ActiveSupport::TestCase.describe(description, true, &blk)
end

# load test helpers
require "rails"
class MyApplication < Rails::Application ; end
adapter = ENV["ARE_DB"] || "sqlite3"

ActiveRecord::Base.logger = Logger.new("log/test.log")
ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.configurations["test"] = YAML.load(this_dir.join("database.yml").open)[adapter]
ActiveRecord::Base.establish_connection "test"

ActiveSupport::Notifications.subscribe(/active_record.sql/) do |event, _, _, _, hsh|
  ActiveRecord::Base.logger.info hsh[:sql]
end

require "factory_girl"
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each{ |file| require file }

# Load base/generic schema
require this_dir.join("schema/version")
require this_dir.join("schema/generic_schema")
adapter_schema = this_dir.join("schema/#{adapter}_schema.rb")
require adapter_schema if File.exists?(adapter_schema)

Dir[File.dirname(__FILE__) + "/models/*.rb"].each{ |file| require file }
