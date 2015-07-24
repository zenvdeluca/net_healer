require 'rufus-scheduler'
require 'redis'
require 'redis-namespace'
require 'json'
require 'dotenv'
Dotenv.load
require_relative '../app_config'


redis_server=AppConfig::REDIS.server
redis_connection = Redis.new(:host => redis_server)
namespaced_current = Redis::Namespace.new('healer_current', redis: redis_connection)
namespaced_history = Redis::Namespace.new('healer_history', redis: redis_connection)
scheduler = Rufus::Scheduler.new

pattern = '*_packets_dump'

scheduler.every '5s' do
  current = []
  payloads_raw = {}
  payloads = []
  begin
    redis_connection.scan_each(:match => pattern) {|key| current << key.split('_')[0] }
  rescue
    puts "#{Time.now} - [ERROR] - Failed to connect at Redis :( - [#{redis_server}]"
    next
  end
  if current.empty?
    puts "#{Time.now} - [INFO] - no new attack reports found - [#{redis_server}]"
    next
  end

  puts "#{Time.now} - Fetching FastNetMon attack reports - [#{redis_server}]"

  current.each do |k|
    payloads_raw[k] = {
      information: redis_connection.get("#{k}_information"),
      flow_dump: redis_connection.get("#{k}_flow_dump"),
      packets_dump: redis_connection.get("#{k}_packets_dump")
    }

    redis_connection.del("#{k}_information","#{k}_flow_dump","#{k}_packets_dump")
  end

  payloads_raw.each do |key,value|
    info = payloads_raw[key][:information].split("\n").map { |lv| k,v = lv.split(':') ; next if k.nil? ; k.gsub!(' ','_') ;v.strip! ; k.downcase!;[ k,v ] }.select { |_,value| not value.nil? }.to_h
    flow_dump = payloads_raw[key][:flow_dump].split("\n").reject! { |l| l.empty? } unless payloads_raw[key][:flow_dump].nil?
    packets_dump = payloads_raw[key][:packets_dump].split("\n").reject! { |l| l.empty? || !l.include?('sample')} unless payloads_raw[key][:packets_dump].nil?
    
    payloads << { information: info,
                  flow_dump: flow_dump,
                  packets_dump: packets_dump
    }

  end

  puts "#{Time.now} - Feeding Healer analyzer - [#{redis_server}]"

  payloads.each do |attack_report|
    puts " * Added attack report:" + attack_report[:information]['ip']
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    key = attack_report[:information]['ip'] + '-' + timestamp
    namespaced_current.set(key, attack_report)
    namespaced_history.set(key, attack_report)
    namespaced_current.expire(key, AppConfig::THRESHOLDS.expire)
    #puts JSON.pretty_generate(JSON.parse(attack_report.to_json))
  end

  #
  # Call to analyzer
  #

end

scheduler.join
