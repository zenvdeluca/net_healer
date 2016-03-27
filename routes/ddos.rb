require 'uri'
require_relative '../lib/nethealer.rb'

class Healer
  

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
      return body(site_status.to_json)

    end

    get "/ddos/reports/?:p1?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      $namespaced_current.scan_each(:match => pattern) {|key| current << eval($namespaced_current.get(key)) }
      reports = report_initializer(current)

      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else

        aggregate = report_aggregate(reports)

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
      current = site_status
      return body(current.to_json) if current[:status] == 'clear'
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
