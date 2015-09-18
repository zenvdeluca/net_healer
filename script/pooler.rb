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
$influxdb_events = InfluxDB::Client.new 'events', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password
$influxdb_graphite = InfluxDB::Client.new 'graphite', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password

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

$debug = 2
$count = 5

def fetch_fastnetmon_redis(queue)
  payloads_raw = {}
  queue.each do |ip|

    payloads_raw[ip] = {
      site: ip.split('_')[0],
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
      next if info["attack_details"]["attack_direction"] == 'outgoing' # ignore fastnetmon outgoing alerts
      flow_dump = payloads_raw[key][:flow_dump].split("\n").reject! { |l| l.empty? } unless payloads_raw[key][:flow_dump].nil?
      packets_dump = payloads_raw[key][:packets_dump].split("\n").reject! { |l| l.empty? || !l.include?('sample')} unless payloads_raw[key][:packets_dump].nil?

      payloads << { site: payloads_raw[key][:site],
                    information: info,
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
  if $count > 15
    puts "#{Time.now} - [INFO] - Running garbage collection..." if $debug == 2
    $notifications_warning = []
    $notifications_critical = []
    gc = []
    pattern = '*_information'
    $redis_connection.scan_each(:match => pattern) {|key| gc << key.rpartition('_')[0] }
    gc.each do |junk|
      puts "removing null key for #{junk}" if $debug == 2
      #$redis_connection.del("#{junk}_information")
      #$redis_connection.del("#{junk}_flow_dump")
      $redis_connection.del("#{junk}_packets_dump")
    end
    $count = 0
  end
  $count += 1
  return true
end


#
# Schedulers
#

# watch redis for FastNetMon Attack Reports. Parse and Feed to NET HEALER

scheduler.every '5s' do
  current = []
  pattern = '*_packets_dump'
  begin
    $redis_connection.scan_each(:match => pattern) {|key| current << key.rpartition('_')[0].rpartition('_')[0] }
  rescue
    puts "#{Time.now} - [ERROR] - Failed to connect to Redis :( - [#{nethealer_server}]"
    next
  end

  if current.empty?
    puts "#{Time.now} - [INFO] - no new attack reports found - [#{nethealer_server}]" if $debug >= 2
    next
  end

  puts "#{Time.now} - [INFO] - Fetching FastNetMon detected attack reports - [#{nethealer_server}]" if $debug >= 1
  payloads_raw = fetch_fastnetmon_redis(current)
  payloads = parse_fastnetmon_redis(payloads_raw)

  puts "#{Time.now} - [INFO] - Feeding Healer analyzer - [#{nethealer_server}]" if $debug >= 1

  #feed net healer queue
  feed_nethealer(payloads)
  #call garbage collection function
  gc_fastnetmon_redis

  puts "#{Time.now} - [INFO] - Back to listen state."
end


# Graph vertical markdown. NET HEALER API query - Grafana: warning[yellow] & critical[red]

last_data = nil
data = ''

scheduler.every '5s' do

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
    puts "|Attack| - #{Time.now}"
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

scheduler.every '5s' do
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


#
# Notification schedulers
#

pagerduty_enabled = true unless (AppConfig::PAGERDUTY.key == "") || AppConfig::PAGERDUTY.key.nil? 
pagerduty = Pagerduty.new(AppConfig::PAGERDUTY.key) if pagerduty_enabled

$notifications_warning = []
$notifications_critical = []

scheduler.every '10s' do
  response = JSON.parse(healer['ddos/status'].get)
  status = response['status']
  target = response['target']

  case status
  when 'clear'
    print '!'

  when 'warning'
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}"}
    reports = JSON.parse(healer['ddos/reports/capture'].get)
    reports = reports['reports']
    capture = {}
    reports.each { |k,v| capture["#{k}"] = v.delete('capture') }

    message = <<MESSAGE_END
From: DDoS Detection <#{AppConfig::NOTIFICATIONS.smtp_from}>
To: Network Operations <#{AppConfig::NOTIFICATIONS.smtp_to}>
Subject: [WARNING] - Possible DDoS - targets: #{info}

Healer Dashboard: https://netmonitor.zdsys.com 

Attack info:
#{reports.to_yaml}

Packet capture:
#{capture.to_yaml}

MESSAGE_END

    unless $notifications_warning.include?(message)
      Net::SMTP.start(AppConfig::NOTIFICATIONS.smtp) do |smtp|
        smtp.send_message message, AppConfig::NOTIFICATIONS.smtp_from,AppConfig::NOTIFICATIONS.smtp_to
      end
      incident = pagerduty.trigger("DDoS WARNING: #{reports.to_yaml}") if pagerduty_enabled
      puts "|Notifications_Warning_Sent| - #{Time.now}"
      
    else
      puts "|Notifications_Warning_Skip| - #{Time.now}"
    end
    $notifications_warning = $notifications_warning | [message]
  
  else
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}"}
    reports = JSON.parse(healer['ddos/reports/capture'].get)
    reports = reports['reports']
    capture = {}
    reports.each { |k,v| capture["#{k}"] = v.delete('capture') }
  
    message = <<MESSAGE_END
From: DDoS Detection <#{AppConfig::NOTIFICATIONS.smtp_from}>
To: Network Operations <#{AppConfig::NOTIFICATIONS.smtp_to}>
Subject: [CRITICAL] - DDoS Attack - targets: #{info}

Healer Dashboard: https://#{AppConfig::NETHEALER.influxdb}

Attack info:
#{reports.to_yaml}

Packet capture:
#{capture.to_yaml}


MESSAGE_END


    unless $notifications_critical.include?(message)

      Net::SMTP.start(AppConfig::NOTIFICATIONS.smtp) do |smtp|
        smtp.send_message message, AppConfig::NOTIFICATIONS.smtp_from,AppConfig::NOTIFICATIONS.smtp_to
      end
      incident = pagerduty.trigger("DDoS CRITICAL: #{reports.to_yaml}") if pagerduty_enabled
      puts "|Notifications_Critical_Sent| - #{Time.now}"

    else
      puts "|Notifications_Critical_Skip| - #{Time.now}"
    end
    $notifications_critical = $notifications_critical | [message]
  end

end



scheduler.join
