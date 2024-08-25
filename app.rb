# frozen_string_literal: true

require "bundler/inline"

# Gemfile
gemfile(true) do
  source "https://rubygems.org"

  gem "dotenv", "~> 3.1"
  gem "rackup", "~> 2.1"
  gem "puma", "~> 6.4"
  gem "rails", "~> 7.2"
  gem "sqlite3", "~> 2.0"

  group :development do
    gem "rubocop-performance"
    gem "rubocop-rails"
  end
end

require "dotenv"
Dotenv.load

require "puma/configuration"
require "rails"
require "action_controller/railtie"

# Controllers
class WelcomeController < ActionController::Base
  def index
    render inline: "Hello World!"
  end
end

# Application Configurations
#
# https://guides.rubyonrails.org/configuring.html
# https://api.rubyonrails.org/v7.2.1/classes/Rails/Application.html
class App < Rails::Application
  config.root = __dir__

  config.enable_reloading                  = false
  config.eager_load                        = true
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.logger   = ActiveSupport::Logger.new(STDOUT)
                                         .tap { |logger| logger.formatter = ::Logger::Formatter.new }
                                         .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  config.log_tags = [ :request_id ]

  # Routes
  routes.append do
    root to: "welcome#index"
  end
end

App.initialize!

# Puma Server
# https://github.com/puma/puma/blob/master/lib/puma/launcher.rb
puma_config = Puma::Configuration.new do |config|
  config.app App

  max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
  min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
  config.threads min_threads_count, max_threads_count

  if Rails.env.production?
    require "concurrent-ruby"
    worker_count = Integer(ENV.fetch("WEB_CONCURRENCY") { Concurrent.physical_processor_count })
    config.workers worker_count if worker_count > 1
  end
  config.worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

  config.port ENV.fetch("PORT") { 3000 }
  config.environment ENV.fetch("RAILS_ENV") { "development" }
  config.pidfile ENV.fetch("PIDFILE") { "tmp/server.pid" }

  config.plugin :tmp_restart
end

launcher = Puma::Launcher.new(puma_config)

begin
  launcher.run
rescue Interrupt
  puts "* Gracefully stopping, waiting for requests to finish"
  launcher.stop
  puts "* Goodbye!"
end
