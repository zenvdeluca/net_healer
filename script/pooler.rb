#!/usr/bin/env ruby
require 'rufus-scheduler'
require 'redis'
require 'redis-namespace'
require 'json'
require 'dotenv'
require 'rest-client'
require 'influxdb'
require 'net/smtp'
require 'pagerduty'
require 'yaml'

Dotenv.load
require_relative '../app_config'

nethealer_server=AppConfig::NETHEALER.server
#$influxdb_events = InfluxDB::Client.new 'events', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password
$influxdb_events = $influxdb_graphite = InfluxDB::Client.new 'graphite', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password

$redis_connection = Redis.new(:host => nethealer_server)
$namespaced_current = Redis::Namespace.new('healer_current', redis: $redis_connection)
$namespaced_history = Redis::Namespace.new('healer_history', redis: $redis_connection)
scheduler = Rufus::Scheduler.new

healer = RestClient::Resource.new(
  "https://#{nethealer_server}/healer/v1/",
  #user: Config::NETHEALER.user,
  #password: Config::NETHEALER.password,
  headers: { content_type: 'application/json' },
  verify_ssl: false
)

$debug = 1
$count = 1

#
# Schedulers
#

# Graph vertical markdown. NET HEALER API query - Grafana: warning[yellow] & critical[red]

last_data = nil
data = ''

scheduler.every '15s' do

  response = JSON.parse(healer['ddos/status'].get)
  status = response['status']
  target = response['target']

  case status
  when 'clear'
    print '!'
  when 'warning'
    puts "|Warning| - #{Time.now}"
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}(#{v})"}
    last_data = data
    begin last_data.delete(:series) rescue puts 'ok' end
    data = {
      values: { type: "WARNING", info: info.to_s, },
    }
    $influxdb_events.write_point('nethealer', data) if data != last_data
  else
    puts "|Critical| - #{Time.now}"
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}(#{v})"}
    last_data = data
    begin last_data.delete(:series) rescue puts 'ok' end
    data = {
      values: { type: "CRITICAL", info: info.to_s },
    }
    $influxdb_events.write_point('nethealer', data) if data != last_data
  end

end

# Calculate in/out bps ratio -- consider refactor

scheduler.every '15s' do
  total_bps = $influxdb_graphite.query "select last(value) from total where resource = 'bps' group by direction,resource"
  ratio_bps = total_bps[0]['values'].first['last'].to_f / total_bps[1]['values'].first['last'].to_f
  unless ratio_bps == Float::INFINITY
    payload_bps = { values: { info: ratio_bps } }
  else
    payload_bps = { values: { info: 0 } }
  end

  total_pps = $influxdb_graphite.query "select last(value) from total where resource = 'pps' group by direction,resource"
  ratio_pps = total_pps[0]['values'].first['last'].to_f / total_pps[1]['values'].first['last'].to_f
  unless ratio_pps == Float::INFINITY
    payload_pps = { values: { info: ratio_pps } }
  else
    payload_pps = { values: { info: 0 } }
  end

  $influxdb_events.write_point('ratio_bps', payload_bps)
  $influxdb_events.write_point('ratio_pps', payload_pps)
end

scheduler.join
