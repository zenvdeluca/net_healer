require 'uri'
require_relative '../lib/nethealer.rb'

class Healer

  configure do
    set :authorized, AppConfig::NETHEALER.whitelist
    set :allow_cmds, AppConfig::NETHEALER.allow_cmds
    set :allow_users, AppConfig::NETHEALER.allow_users
  end

  def get_headers()
    Hash[*env.select {|k,v| k.start_with? 'HTTP_'}
         .collect {|k,v| [k.sub(/^HTTP_/, ''), v]}
         .collect {|k,v| [k.split('_').collect(&:capitalize).join('-'), v]}
         .sort
         .flatten]
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

    get "/ddos/mitigation/?" do
      blackhole, akamai = mitigation_status
      body({akamai: akamai, blackhole: blackhole, timestamp: Time.now.strftime("%Y%m%d-%H%M%S")}.to_json)
    end

    get "/ddos/mitigation/:p1/add/:p2/:p3/?" do
      auth_user = get_headers['X-Forwarded-User']
      unless settings.authorized.include?(request.ip) && settings.allow_cmds.include?(params[:p1]) && settings.allow_users.include?(auth_user)
        status 403
        return body('Not authorized')
      end

      cmd = `/usr/local/sbin/#{params[:p1]} --add #{params[:p2]}/#{params[:p3]}`
      blackhole, akamai = mitigation_status
      puts "#{Time.now.strftime("%Y%m%d-%H%M%S")} -- #{auth_user} added #{params[:p1]} route for #{params[:p2]}/#{params[:p3]}"
      body({akamai: akamai, blackhole: blackhole, timestamp: Time.now.strftime("%Y%m%d-%H%M%S"), user: auth_user}.to_json)
    end

    get "/ddos/mitigation/:p1/remove/:p2/:p3/?" do
      auth_user = get_headers['X-Forwarded-User']
      unless settings.authorized.include?(request.ip) && settings.allow_cmds.include?(params[:p1]) && settings.allow_users.include?(auth_user)
        status 403
        return body('Not authorized')
      end

      cmd = `/usr/local/sbin/#{params[:p1]} --del #{params[:p2]}/#{params[:p3]}`
      blackhole, akamai = mitigation_status
      puts "#{Time.now.strftime("%Y%m%d-%H%M%S")} - #{auth_user} - removed #{params[:p1]} route for #{params[:p2]}/#{params[:p3]}"
      body({akamai: akamai, blackhole: blackhole, timestamp: Time.now.strftime("%Y%m%d-%H%M%S"), user: auth_user}.to_json)
    end


  end

end
