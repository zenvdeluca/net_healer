#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load
require 'rufus-scheduler'
require 'json'
require 'influxdb'
require_relative '../app_config'

$influxdb_events = InfluxDB::Client.new 'graphite', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password

scheduler = Rufus::Scheduler.new

#
# Schedulers
#

# Calculate in/out bps ratio -- consider refactor

scheduler.every '5s' do
  total_bps = $influxdb_events.query "select last(value) from total where resource = 'bps' group by direction,resource"
  ratio_bps = total_bps[0]['values'].first['last'].to_f / total_bps[1]['values'].first['last'].to_f
  unless ratio_bps == Float::INFINITY
    payload_bps = { values: { info: ratio_bps } }
  else
    payload_bps = { values: { info: 100 } }
  end

  total_pps = $influxdb_events.query "select last(value) from total where resource = 'pps' group by direction,resource"
  ratio_pps = total_pps[0]['values'].first['last'].to_f / total_pps[1]['values'].first['last'].to_f
  unless ratio_pps == Float::INFINITY
    payload_pps = { values: { info: ratio_pps } }
  else
    payload_pps = { values: { info: 100 } }
  end

  $influxdb_events.write_point('ratio_bps', payload_bps)
  $influxdb_events.write_point('ratio_pps', payload_pps)
end

scheduler.join
