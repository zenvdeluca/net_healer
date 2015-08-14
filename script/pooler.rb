#!/usr/bin/env ruby
require 'rufus-scheduler'
require 'redis'
require 'redis-namespace'
require 'json'
require 'dotenv'
Dotenv.load
require_relative '../app_config'

redis_server=AppConfig::REDIS.server
$redis_connection = Redis.new(:host => redis_server)
$namespaced_current = Redis::Namespace.new('healer_current', redis: $redis_connection)
$namespaced_history = Redis::Namespace.new('healer_history', redis: $redis_connection)
scheduler = Rufus::Scheduler.new

$debug = 1

def fetch_fastnetmon_redis(queue)
  payloads_raw = {}
  queue.each do |ip|
    payloads_raw[ip] = {
      information: $redis_connection.get("#{ip}_information"),
      flow_dump: $redis_connection.get("#{ip}_flow_dump"),
      packets_dump: $redis_connection.get("#{ip}_packets_dump")
    }
    # After import, erase from Redis (fastnetmon raw format)
    $redis_connection.del("#{ip}_information","#{ip}_flow_dump","#{ip}_packets_dump")
  end
  payloads_raw
end

def parse_fastnetmon_redis(payloads_raw)
  payloads = []
  payloads_raw.each do |key,value|
    begin
      info = JSON.parse(payloads_raw[key][:information])
      flow_dump = payloads_raw[key][:flow_dump].split("\n").reject! { |l| l.empty? } unless payloads_raw[key][:flow_dump].nil?
      packets_dump = payloads_raw[key][:packets_dump].split("\n").reject! { |l| l.empty? || !l.include?('sample')} unless payloads_raw[key][:packets_dump].nil?
      
      payloads << { information: info,
                    flow_dump: flow_dump,
                    packets_dump: packets_dump
      }
    rescue Exception => e  
      puts e.message if $debug >= 1
      puts e.backtrace.inspect if $debug == 2
      puts "Failed to parse #{key}: #{payloads_raw[key]} ignoring null report..." if $debug >= 1
      next
    end
  end
  payloads
end

def feed_nethealer(payloads)
  payloads.each do |attack_report|
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    key = attack_report[:information]['ip'] + '-' + timestamp
    $namespaced_current.set(key, attack_report)
    $namespaced_history.set(key, attack_report)
    $namespaced_current.expire(key, AppConfig::THRESHOLDS.expire)
    puts JSON.pretty_generate(JSON.parse(attack_report.to_json)) if $debug == 2
    puts " * Added attack report:" + attack_report[:information]['ip'] if $debug >= 1
  end
  return true
end

def gc_fastnetmon_redis
  if $count > 20
    puts "#{Time.now} - [INFO] - Running garbage collection..." if debug == 2
    gc = []
    $redis_connection.scan_each(:match => pattern) {|key| gc << key.split('_')[0] }
    pattern = '*_information'
    gc.each do |ip|
      puts "removing null key for #{ip}" if debug == 2
      $redis_connection.del("#{ip}_packets_dump")
    end
  end
  $count = 0
  return true
end
    



$count = 0
scheduler.every '5s' do
  current = []
  pattern = '*_packets_dump'
  begin
    $redis_connection.scan_each(:match => pattern) {|key| current << key.split('_')[0] }
  rescue
    puts "#{Time.now} - [ERROR] - Failed to connect to Redis :( - [#{redis_server}]"
    next
  end
  
  if current.empty?
    puts "#{Time.now} - [INFO] - no new attack reports found - [#{redis_server}]" if $debug >= 2
    next
  end
  $count += 1 
  puts "#{Time.now} - [INFO] - Fetching FastNetMon detected attack reports - [#{redis_server}]" if $debug >= 1
  payloads_raw = fetch_fastnetmon_redis(current)
  payloads = parse_fastnetmon_redis(payloads_raw)

  puts "#{Time.now} - [INFO] - Feeding Healer analyzer - [#{redis_server}]" if $debug >= 1

  #feed net healer queue
  feed_nethealer(payloads)

  #call garbage collection function
  gc_fastnetmon_redis

  puts "#{Time.now} - [INFO] - Back to listen state."
end

scheduler.join
