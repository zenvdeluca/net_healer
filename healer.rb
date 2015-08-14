require 'sinatra'
require 'sinatra/cross_origin'
require 'sinatra/namespace'
require 'sinatra/json'
require 'ipaddr'

require_relative 'app_config'

class Healer < Sinatra::Base
  API_VERSION = '1'
  API_PREFIX = 'healer'
  API_URL = "/#{API_PREFIX}/v#{API_VERSION}"

  register Sinatra::CrossOrigin
  register Sinatra::Namespace
  set :allow_origin, :any
  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, true
  set :max_age, '1728000'
  set :expose_headers, ['Content-Type']
  Rack::Utils.key_space_limit = 262144

  configure do
    enable :cross_origin
  end

  before do
    if request.request_method == 'OPTIONS'
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'POST'
      halt 200
    end
  end
end

def require_directory(directory)
  Dir[File.join(File.dirname(__FILE__), directory, '**')].each do |route|
    require route
  end
end

%w[jobs lib routes models serializers].each { |dir| require_directory dir }
