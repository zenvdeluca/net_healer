require 'flowdock'

class Actions

  def critical_bgp(current)
    flows_token = AppConfig::FLOWDOCK.tokens
    site = AppConfig::NOTIFICATIONS.location.upcase
    targets = current[:target].map {|k,v| k}
    *discard, akamai = mitigation_status
    targets.each do |ip|
      cidr = ip.split('.')[0..-2].join('.') + '.0/24'
      next if akamai.include?(cidr)
      cmd = `/usr/local/sbin/akamai --add #{cidr}`
      flows_token.each do |flow_token|
        flow = Flowdock::Flow.new(:api_token => flow_token, :external_user_name => "NetHealer BGP")
        flow.push_to_chat(:content => ":ambulance: [NETHEALER-#{site.upcase}] - AKAMAI(PROLEXIC) MITIGATION ENABLED ON #{cidr}\n@team", :tags => ["DDoS","Critical","Mitigation","Enabled"])
        flow.push_to_chat(:content => "click to disable AKAMAI routing for #{cidr} ==> #{AppConfig::NETHEALER.netportal}/ddos/#{site.downcase}/mitigation/akamai/remove/#{cidr.split('/')[0]}")     
      end
      puts "|BGP_Advertised #{cidr}| - #{Time.now}"
    end
    return "runned"
  end
end
