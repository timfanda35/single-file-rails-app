# frozen_string_literal: true

require "bundler/inline"

# Gemfile
gemfile(true) do
  source "https://rubygems.org"

  gem "dotenv", "~> 3.1"
  gem "rackup", "~> 2.1"
  gem "puma", "~> 6.4"
  gem "rails", "~> 7.2"

  # Bundle will auto require, we have to require the active_record first, then litestack can register the adapter
  gem "litestack", "~> 0.4.4", require: false

  group :development do
    gem "rubocop-performance"
    gem "rubocop-rails"
  end
end

Dotenv.load

require "puma/configuration"
require "active_record/railtie"
require "action_controller/railtie"
require "litestack"

# Database
# database = "db/#{ENV.fetch("RAILS_ENV", "development")}.sqlite3"
database = "db/#{ENV.fetch("RAILS_ENV", "development")}/#{ENV.fetch("RAILS_ENV", "development")}.sqlite3"

ENV["DATABASE_URL"] = "litedb:#{database}"

ActiveRecord::Base.establish_connection
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Schema.define do
  create_table :posts, if_not_exists: true do |t|
    t.string :title
    t.text :content

    t.timestamps
  end
end

# Models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

class Post < ApplicationRecord
  validates :title, :content, presence: true
end

# Controllers
class WelcomeController < ActionController::Base
  def index
    render inline: "Hello World!"
  end
end

class PostsController < ActionController::Base
  before_action :set_post, only: %w[show update destroy]

  def index
    @posts = Post.all
    render json: { records: @posts, total_results: @posts.size }
  end

  def create
    @post = Post.new(create_params)

    if @post.save
      render json: { record: @post }
    else
      render json: { record: @post.as_json(methods: :errors) }, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(update_params)
      render json: { record: @post }
    else
      render json: { record: @post.as_json(methods: :errors) }, status: :unprocessable_entity
    end
  end

  def show
    render json: { record: @post }
  end

  def destroy
    if @post.destroy
      render json: { record: @post }
    else
      render json: { record: @post.as_json(methods: :errors) }, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def create_params
    params.require(:post).permit(:title, :content)
  end

  def update_params
    params.require(:post).permit(:title, :content)
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
    resources :posts
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
