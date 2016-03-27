require 'redis'
require 'redis-namespace'
require 'uri'
require 'resolv'

class Healer
  redis_server=AppConfig::NETHEALER.server
  $redis_connection = Redis.new(:host => redis_server)
  $namespaced_current = Redis::Namespace.new('healer_current', redis: $redis_connection)
  $namespaced_history = Redis::Namespace.new('healer_history', redis: $redis_connection)

  def report_initializer(queue)
    if queue.empty?
      return false
    end
    return queue.group_by {|report| report[:information]['ip']}
  end

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
        if info["attack_details"]["attack_direction"] == 'outgoing' # ignore fastnetmon outgoing alerts
          print 'O' if $debug == 1
          puts "removing outgoing report for #{key}" if $debug == 2
          $redis_connection.del("#{key}_information")
          $redis_connection.del("#{key}_flow_dump")
          $redis_connection.del("#{key}_packets_dump")
          next
        end
        flow_dump = payloads_raw[key][:flow_dump].split("\n").reject! { |l| l.empty? } unless payloads_raw[key][:flow_dump].nil?
        #packets_dump = payloads_raw[key][:packets_dump].split("\n").reject! { |l| l.empty? || !l.include?('sample')} unless payloads_raw[key][:packets_dump].nil?

        payloads << { site: payloads_raw[key][:site],
                      information: info,
                      flow_dump: flow_dump,
                      #packets_dump: packets_dump
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

  def status
    current = []
    warning = {}
    critical = {}

    pattern = '*' + Time.now.strftime("%Y") + '*'
    $namespaced_current.scan_each(:match => pattern) {|key| current << eval($namespaced_current.get(key)) }
    reports = report_initializer(current)
    unless reports
      return { status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }
    else
      summary = reports.map { |k,v| { "#{k}" => v.length } }
      brief = summary.reduce Hash.new, :merge
      brief.each do |k,v|
        warning[k] = v if v >= AppConfig::THRESHOLDS.warning
        critical[k] = v if v >= AppConfig::THRESHOLDS.critical
      end

      return { status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") } if warning.empty? && critical.empty?
      return { status: 'warning', target: warning, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") } if critical.empty?
      return { status: 'critical', target: critical, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }
    end
  end


  namespace API_URL do

    get "/ddos/brief/?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      $namespaced_current.scan_each(:match => pattern) {|key| current << eval($namespaced_current.get(key)) }
      reports = report_initializer(current)
      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else
        summary = reports.map { |k,v| { "#{k}" => v.length } }
        brief = summary.reduce Hash.new, :merge
        body({reports: brief, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      end
    end

    get "/ddos/status/?" do
      return body(status.to_json)

    end

    get "/ddos/reports/?:p1?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      $namespaced_current.scan_each(:match => pattern) {|key| current << eval($namespaced_current.get(key)) }
      reports = report_initializer(current)

      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else

        aggregate = {}
        reports.each do |k,v|
          aggregate["#{k}"] = {}
          begin
            aggregate["#{k}"]['fqdn'] = Resolv.new.getname(k)
          rescue
            aggregate["#{k}"]['fqdn'] = 'no.reverse.dns'
          end
          aggregate["#{k}"]['site'] = AppConfig::NOTIFICATIONS.location
          aggregate["#{k}"]['alerts'] = 0
          aggregate["#{k}"]['protocol'] = []
          aggregate["#{k}"]['incoming'] = {}

          aggregate["#{k}"]['incoming']['total'] = {}
          aggregate["#{k}"]['incoming']['total']['mbps'] = 0
          aggregate["#{k}"]['incoming']['total']['pps'] = 0
          aggregate["#{k}"]['incoming']['total']['flows'] = 0

          aggregate["#{k}"]['incoming']['tcp'] = {}
          aggregate["#{k}"]['incoming']['tcp']['mbps'] = 0
          aggregate["#{k}"]['incoming']['tcp']['pps'] = 0
          aggregate["#{k}"]['incoming']['tcp']['syn'] = {}
          aggregate["#{k}"]['incoming']['tcp']['syn']['mbps'] = 0
          aggregate["#{k}"]['incoming']['tcp']['syn']['pps'] = 0

          aggregate["#{k}"]['incoming']['udp'] = {}
          aggregate["#{k}"]['incoming']['udp']['mbps'] = 0
          aggregate["#{k}"]['incoming']['udp']['pps'] = 0

          aggregate["#{k}"]['incoming']['icmp'] = {}
          aggregate["#{k}"]['incoming']['icmp']['mbps'] = 0
          aggregate["#{k}"]['incoming']['icmp']['pps'] = 0

          aggregate["#{k}"]['capture'] = [] if params[:p1] == 'capture'

          reports["#{k}"].each do |item|
            aggregate["#{k}"]['alerts'] += 1
            aggregate["#{k}"]['attack_type'] = 'unknown' && item[:information]['attack_details']['attack_type']
            #aggregate["#{k}"]['direction'] = item[:information]['attack_details']['attack_direction']
            aggregate["#{k}"]['protocol'] = aggregate["#{k}"]['protocol'] | [item[:information]['attack_details']['attack_protocol']]

            aggregate["#{k}"]['incoming']['total']['mbps'] = [aggregate["#{k}"]['incoming']['total']['mbps'],item[:information]['attack_details']['total_incoming_traffic']].max
            aggregate["#{k}"]['incoming']['total']['pps'] = [aggregate["#{k}"]['incoming']['total']['pps'],item[:information]['attack_details']['total_incoming_pps']].max
            aggregate["#{k}"]['incoming']['total']['flows'] = [aggregate["#{k}"]['incoming']['total']['flows'],item[:information]['attack_details']['total_incoming_flows']].max


            aggregate["#{k}"]['incoming']['tcp']['mbps'] = [aggregate["#{k}"]['incoming']['tcp']['mbps'],item[:information]['attack_details']['incoming_tcp_traffic']].max
            aggregate["#{k}"]['incoming']['tcp']['pps'] = [aggregate["#{k}"]['incoming']['tcp']['pps'],item[:information]['attack_details']['incoming_tcp_pps']].max
            aggregate["#{k}"]['incoming']['tcp']['syn']['mbps'] = [aggregate["#{k}"]['incoming']['tcp']['syn']['mbps'],item[:information]['attack_details']['incoming_syn_tcp_traffic']].max
            aggregate["#{k}"]['incoming']['tcp']['syn']['pps'] = [aggregate["#{k}"]['incoming']['tcp']['syn']['pps'],item[:information]['attack_details']['incoming_syn_tcp_pps']].max

            aggregate["#{k}"]['incoming']['udp']['mbps'] = [aggregate["#{k}"]['incoming']['udp']['mbps'],item[:information]['attack_details']['incoming_udp_traffic']].max
            aggregate["#{k}"]['incoming']['udp']['pps'] = [aggregate["#{k}"]['incoming']['udp']['pps'],item[:information]['attack_details']['incoming_udp_pps']].max

            aggregate["#{k}"]['incoming']['icmp']['mbps'] = [aggregate["#{k}"]['incoming']['icmp']['mbps'],item[:information]['attack_details']['incoming_icmp_traffic']].max
            aggregate["#{k}"]['incoming']['icmp']['pps'] = [aggregate["#{k}"]['incoming']['icmp']['pps'],item[:information]['attack_details']['incoming_icmp_pps']].max

            if params[:p1] == 'capture'
              begin
                item[:flow_dump].each { |pcap_line| aggregate["#{k}"]['capture'] << pcap_line }
              rescue
              end
            end

          end
        end

        # normalize bps => mbps

        aggregate.each do |k,v|
          aggregate["#{k}"]['incoming']['total']['mbps'] = (aggregate["#{k}"]['incoming']['total']['mbps'] / 1048576.0).round(2)
          aggregate["#{k}"]['incoming']['tcp']['mbps'] = (aggregate["#{k}"]['incoming']['tcp']['mbps'] / 1048576.0).round(2)
          aggregate["#{k}"]['incoming']['tcp']['syn']['mbps'] = (aggregate["#{k}"]['incoming']['tcp']['syn']['mbps'] / 1048576.0).round(2)
          aggregate["#{k}"]['incoming']['udp']['mbps'] = (aggregate["#{k}"]['incoming']['udp']['mbps'] / 1048576.0).round(2)
          aggregate["#{k}"]['incoming']['icmp']['mbps'] = (aggregate["#{k}"]['incoming']['icmp']['mbps'] / 1048576.0).round(2)
        end

        body({reports: aggregate, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      end
    end

    get "/ddos/pool/?" do
      current = []
      pattern = '*_information'
      begin
        $redis_connection.scan_each(:match => pattern) {|key| current << key.rpartition('_')[0] }
      rescue
        puts "#{Time.now} - [ERROR] - Failed to connect to Redis :( - [#{AppConfig::NETHEALER.server}]"
        next
      end

      if current.empty?
        puts "#{Time.now} - [INFO] - no new attack reports found - [#{AppConfig::NETHEALER.server}]" if $debug >= 2
        next
      end

      puts "#{Time.now} - [INFO] - Fetching FastNetMon detected attack reports - [#{AppConfig::NETHEALER.server}]" if $debug >= 2
      payloads_raw = fetch_fastnetmon_redis(current)
      payloads = parse_fastnetmon_redis(payloads_raw)
      next if payloads.empty?
      puts "#{Time.now} - [INFO] - Feeding Healer analyzer - [#{AppConfig::NETHEALER.server}]" if $debug >= 2

      #feed net healer queue
      feed_nethealer(payloads)

      return body(Time.now.strftime("%Y%m%d-%H%M%S").to_json)
    end

    get "/ddos/actions/?" do
      current = status
      return body(status.to_json) if current[:status] == 'clear'
      execute = [] ; run = []
      actions = Actions.new

      Actions.instance_methods(false).each do |method|
        if method.to_s.include?(current[:status])
          execute << method
        end
      end

      execute.each do |alert|
        puts "Executing #{alert}"
        run << {alert: alert, status: eval("actions.#{alert.to_s}(current)") }
      end

      return run.to_json
    end

  end

end
