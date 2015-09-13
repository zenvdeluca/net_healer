#!/usr/bin/env ruby
require 'rufus-scheduler'
require 'redis'
require 'redis-namespace'
require 'json'
require 'dotenv'
require 'rest-client'
require 'influxdb'
require 'net/smtp'
require 'yaml'

Dotenv.load
require_relative '../app_config'

nethealer_server=AppConfig::NETHEALER.server
influxdb_events = InfluxDB::Client.new 'events', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password
influxdb_graphite = InfluxDB::Client.new 'graphite', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password

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
  $count += 1
  if $count > 3
    puts "#{Time.now} - [INFO] - Running garbage collection..." if $debug == 2
    gc = []
    pattern = '*_information'
    $redis_connection.scan_each(:match => pattern) {|key| gc << key.rpartition('_')[0] }
    gc.each do |junk|
      puts "removing null key for #{junk}" if $debug == 2
      $redis_connection.del("#{junk}_information")
      $redis_connection.del("#{junk}_flow_dump")
      $redis_connection.del("#{junk}_packets_dump")

    end
    $count = 0
  end
  return true
end

def top_talkers(num)
  top = []
  top_talkers = influxdb_graphite.query "select top(value, cidr, #{num}) from hosts where direction = 'incoming' and resource = 'bps' group by time"
  top_talkers.first["values"].each do |talker|
    next if ( talker["cidr"] =~ /192_161_152_14[4-9]/ ) || ( talker["cidr"] =~ /192_161_152_15[1-9]/ )
    top << { ipv4: talker["cidr"], bps: talker["top"] }
  end
  top
end

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


# Query nethealer API for Graph vertical markdown. warning[yellow] & critical[red]

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
    influxdb_events.write_point('nethealer', data) if data != last_data
  else
    puts "|Attack| - #{Time.now}"
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}(#{v})"}
    last_data = data
    begin last_data.delete(:series) rescue puts 'ok' end
    data = {
      values: { type: "CRITICAL", info: info.to_s },
    }
    influxdb_events.write_point('nethealer', data) if data != last_data
  end

end

# Calculate in/out bps ratio -- consider refactor/moving to netmon

scheduler.every '5s' do
  total_bps = influxdb_graphite.query "select last(value) from total where resource = 'bps' group by direction,resource"
  ratio_bps = total_bps[0]['values'].first['last'].to_f / total_bps[1]['values'].first['last'].to_f
  payload_bps = { values: { info: ratio_bps } }

  total_pps = influxdb_graphite.query "select last(value) from total where resource = 'pps' group by direction,resource"
  ratio_pps = total_pps[0]['values'].first['last'].to_f / total_pps[1]['values'].first['last'].to_f
  payload_pps = { values: { info: ratio_pps } }

  influxdb_events.write_point('ratio_bps', payload_bps)
  influxdb_events.write_point('ratio_pps', payload_pps)
end



# Notifications

notifications_warning = []
notifications_critical = []

scheduler.every '10s' do
  response = JSON.parse(healer['ddos/status'].get)
  status = response['status']
  target = response['target']

  case status
  when 'clear'
    print '!'

  when 'warning'
    puts "|Notifications_Warning| - #{Time.now}"
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}"}
    reports = JSON.parse(healer['ddos/reports/capture'].get)
    reports = reports['reports']
    capture = {}
    reports.each { |k,v| capture["#{k}"] = v.delete('capture') }
    top = top_talkers(10)

    message = <<MESSAGE_END
From: DDoS Detection <no-reply@zendesk.com>
To: Network Operations <vdeluca@zendesk.com>
Subject: [WARNING] - Possible DDoS - targets: #{info}

Attack info:
#{reports.to_yaml}

TOP Talkers:
#{top.to_yaml}

Packet capture:
#{capture.to_yaml}


MESSAGE_END

    Net::SMTP.start('out.vip.pod5.iad1.zdsys.com') do |smtp|
      smtp.send_message message, 'ddos@zendesk.com','vdeluca@zendesk.com'
    end


  else
    puts "|Attack| - #{Time.now}"
    info = ''
    response['target'].map {|k,v| info = info + "|#{k}(#{v})"}
  end

end



scheduler.join
