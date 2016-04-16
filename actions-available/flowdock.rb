require 'flowdock'

$lastpd = Time.now - 301
$lastinfo = ''

ping_enabled = true
ping_target = '8.8.8.8'
ping_count = 7
ping_timeout = 1

class Actions
  def warning_flowdock(current)
    flows_token = AppConfig::FLOWDOCK.tokens
    site = AppConfig::NOTIFICATIONS.location.downcase
    grafana = AppConfig::GRAFANA.url
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      flows_token.each do |flow_token|
        flow = Flowdock::Flow.new(:api_token => flow_token, :external_user_name => "NetHealer")
        flow.push_to_chat(:content => ":warning: [NETHEALER-#{site.upcase}] - Possible DDoS - target: #{info} \n- Graphs => #{grafana}/dashboard/db/#{site}-bps-pps-flows\n@team", :tags => ["DDoS","Warning"])
        if ping_enabled
          ping = `ping -c #{ping_count} -W #{ping_timeout} #{ping_target} | grep -E "packet loss|min/avg/max"`.split("\n")
          loss = ping[0].split(', ')[2]
          min, avg, max, *discard = ping[1].split('= ')[1].split('/')
          flow.push_to_chat(:content => "[PING-#{site.upcase} #{ping_target}] - #{loss} - Latency: \n- min: #{min}ms, \n- avg: #{avg}ms, \n- max: #{max}ms", :tags => ["DDoS","Critical","Ping"])
        end
      end
      puts "|Flowdock_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Flowdock_Sleep| - #{Time.now}"
    return 'sleep'
  end

  def critical_flowdock(current)
    flows_token = AppConfig::FLOWDOCK.tokens
    site = AppConfig::NOTIFICATIONS.location.downcase
    grafana = AppConfig::GRAFANA.url
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      flows_token.each do |flow_token|
        flow = Flowdock::Flow.new(:api_token => flow_token, :external_user_name => "NetHealer")
        flow.push_to_chat(:content => ":death: [NETHEALER-#{site.upcase}] - 99% confirmed DDoS - target: #{info} \n- Graphs => #{grafana}/dashboard/db/#{site}-bps-pps-flows\n@team", :tags => ["DDoS","Critical"])
        if ping_enabled
          ping = `ping -c #{ping_count} -W #{ping_timeout} #{ping_target} | grep -E "packet loss|min/avg/max"`.split("\n")
          loss = ping[0].split(', ')[2]
          min, avg, max, *discard = ping[1].split('= ')[1].split('/')
          flow.push_to_chat(:content => "[PING-#{site.upcase} #{ping_target}] - #{loss} - Latency: \n- min: #{min}ms, \n- avg: #{avg}ms, \n- max: #{max}ms", :tags => ["DDoS","Critical","Ping"])
        end
      end
      puts "|Flowdock_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Flowdock_Sleep| - #{Time.now}"
    return 'sleep'
  end


end
