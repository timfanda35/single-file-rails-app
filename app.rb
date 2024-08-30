# frozen_string_literal: true

require "bundler/inline"

# Gemfile
gemfile(true) do
  source "https://rubygems.org"

  # Control the require sequence later
  gem "dotenv", "~> 3.1", require: false
  gem "puma", "~> 6.4", require: false
  gem "rails", "~> 7.2", require: false
  gem "litestack", "~> 0.4.4", require: false
  gem "phlex-rails", "~> 1.2", require: false

  group :development do
    gem "rubocop-performance", require: false
    gem "rubocop-rails", require: false
  end
end

# We use the Dotenv.load not Dotenv::Rails.load to load .env
require "dotenv"
Dotenv.load

# Require Rails first, and other later
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "puma"
require "litestack"
require "phlex-rails"

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
    root to: "posts#index"
    resources :posts
  end
end

App.initialize!

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

# Views

# Phlex Base Configuration start
class ApplicationComponent < Phlex::HTML
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::LinkTo
end

class ApplicationView < ApplicationComponent; end

class ApplicationLayout < ApplicationComponent
  include Phlex::Rails::Layout

  def view_template(&block)
    doctype

    html do
      head do
        title { "Single File Rails App" }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        csp_meta_tag
        csrf_meta_tags
      end

      body do
        main(&block)
      end
    end
  end
end

class PostsIndexView < ApplicationView
  def initialize(title:, posts:)
    @title = title
    @posts = posts
  end

  def view_template
    h1 { @title }
    div { link_to "new", new_post_path }
    div do
      @posts.each do |post|
        li { link_to post.title, post_path(post) }
      end
    end
  end
end

class PostsFormView < ApplicationView
  include Phlex::Rails::Helpers::FormFor

  # @param [ActiveRecord] post
  def initialize(post:)
    @post = post
  end

  def view_template
    h1 { @post.new_record? ? plain("New Post") : plain("Edit Post ##{@post.id}") }

    div do
      form_for @post do |f|
        div {
          f.label :title
          f.text_field :title
        }

        div {
          f.label :content
          f.text_area :content
        }

        div {
          link_to "cancel", posts_path
          f.submit
        }
      end
    end
  end
end

class PostsShowView < ApplicationView
  def initialize(post:)
    @post = post
  end

  def view_template
    h1 { @post.title }
    div { plain @post.content }
    div do
      link_to "back", posts_path
      link_to "edit", edit_post_path(@post)
    end
  end
end

# Controllers
class ApplicationController < ActionController::Base
  layout -> { ApplicationLayout }
end

class WelcomeController < ApplicationController
  def index
    render WelcomeIndexView.new(title: "Hello World!")
  end
end

class PostsController < ApplicationController
  before_action :set_post, only: %w[edit update show destroy]

  def index
    @posts = Post.all
    render PostsIndexView.new(title: "Posts", posts: @posts.load_async)
  end

  def new
    render PostsFormView.new(post: Post.new)
  end

  def create
    @post = Post.new(create_params)

    if @post.save
      redirect_to posts_path
    else
      render PostsFormView.new(post: @post)
    end
  end

  def edit
    render PostsFormView.new(post: @post)
  end

  def update
    if @post.update(update_params)
      redirect_to post_path(@post)
    else
      render PostsFormView.new(post: @post)
    end
  end

  def show
    render PostsShowView.new(post: @post)
  end

  def destroy
    if @post.destroy
      redirect_to posts_path
    else
      redirect_to post_path(@post)
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

# Puma Server
# https://github.com/puma/puma/blob/master/lib/puma/launcher.rb
require "puma/configuration"
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
