ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'rspec'
require 'dotenv'
Dotenv.load

require File.expand_path '../../healer.rb', __FILE__

RSpec.configure do |c|
  include Rack::Test::Methods
  def app() described_class end
end
