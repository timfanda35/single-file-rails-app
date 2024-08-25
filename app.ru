# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rack"
  gem "rails", "~> 7.1"
  gem "dotenv-rails"
  gem "sqlite3"

  group :development do
    gem "rubocop-performance"
    gem "rubocop-rails"
  end
end

require "rails/all"

# https://guides.rubyonrails.org/configuring.html
# https://api.rubyonrails.org/v7.2.1/classes/Rails/Application.html
class App < Rails::Application
  config.root                        = __dir__
  config.consider_all_requests_local = true

  config.logger = ActiveSupport::Logger.new(STDOUT)
                                       .tap { |logger| logger.formatter = ::Logger::Formatter.new }
                                       .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  routes.append do
    root to: "welcome#index"
  end
end

class WelcomeController < ActionController::Base
  def index
    render inline: "Hello World!"
  end
end

App.initialize!

Rails.logger.info "Environment: #{Rails.env}"

run App
