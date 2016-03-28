require 'flowdock'

$lastpd = Time.now - 301
$lastinfo = ''

class Actions
  def warning_flowdock(current)
    flows_token = AppConfig::FLOWDOCK.tokens
    flows_token = flows_token.split(',')
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      flows_token.each do |flow_token|
        flow = Flowdock::Flow.new(:api_token => flow_token, :external_user_name => "NetHealer")
        flow.push_to_chat(:content => "[WARNING] - Possible DDoS in #{AppConfig::NOTIFICATIONS.location} - target: #{info}", :tags => ["DDoS","Warning"])
      end
      puts "|Flowdock_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Flowdock_Sleep| - #{Time.now}"
    return 'sleep'
  end

  def critical_flowdock(current)
    flows_token = AppConfig::FLOWDOCK.tokens
    flows_token = flows_token.split(',')
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      flows_token.each do |flow_token|
        flow = Flowdock::Flow.new(:api_token => flow_token, :external_user_name => "NetHealer")
        flow.push_to_chat(:content => "[CRITICAL] - Possible DDoS in #{AppConfig::NOTIFICATIONS.location} - target: #{info}", :tags => ["DDoS","Critical"])
      end
      puts "|Flowdock_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Flowdock_Sleep| - #{Time.now}"
    return 'sleep'
  end


end
