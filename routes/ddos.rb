require 'redis'
require 'redis-namespace'
require 'uri'

class Healer
  redis_connection = Redis.new
  namespaced_current = Redis::Namespace.new('healer_current', redis: redis_connection)
  namespaced_history = Redis::Namespace.new('healer_history', redis: redis_connection)

  namespace API_URL do
    post "/ddos/notify" do
      begin
        payload = URI.decode(request.body.read)
        attack_info = {}
        payload.each_line do |line|
          attack_info[:timestamp] = Time.now.strftime("%Y%m%d-%H%M%S")
          attack_info[:datacenter] = 'IAD1'
          attack_info[:ip] = line.split(': ')[1].chomp! if line.include? 'IP:'
          attack_info[:type] = line.split(': ')[1].chomp! if line.include? 'Attack type:'
          attack_info[:init_power_pps] = line.split(': ')[1].chomp! if line.include? 'Initial attack power:'
          attack_info[:direction] = line.split(': ')[1].chomp! if line.include? 'Attack direction:'
          attack_info[:protocol] = line.split(': ')[1].chomp! if line.include? 'Attack Protocol:'
          attack_info[:total_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Total incoming traffic:'
          attack_info[:total_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Total incoming pps:'
          attack_info[:total_incoming_flows] = line.split(': ')[1].chomp! if line.include? 'Total incoming flows:'
          attack_info[:avg_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Average incoming traffic:'
          attack_info[:avg_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Average incoming pps:'
          attack_info[:avg_incoming_flows] = line.split(': ')[1].chomp! if line.include? 'Average incoming flows:'
          attack_info[:frag_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Incoming ip fragmented traffic:'
          attack_info[:frag_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Incoming ip fragmented pps:'
          attack_info[:tcp_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Incoming tcp traffic:'
          attack_info[:tcp_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Incoming tcp pps:'
          attack_info[:syn_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Incoming syn tcp traffic:'
          attack_info[:syn_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Incoming syn tcp pps:'
          attack_info[:udp_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Incoming udp traffic:'
          attack_info[:udp_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Incoming udp pps:'
          attack_info[:icmp_incoming_traffic] = line.split(': ')[1].chomp! if line.include? 'Incoming icmp traffic:'
          attack_info[:icmp_incoming_pps] = line.split(': ')[1].chomp! if line.include? 'Incoming icmp pps:'
          attack_info[:avg_incoming_pktsize] = line.split(': ')[1].chomp! if line.include? 'Average packet size for incoming traffic:'
        end
      rescue
        status 500
        return 'invalid format'
      end
      timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
      namespaced_current.set(timestamp, attack_info)
      namespaced_current.expire(timestamp, AppConfig::THRESHOLDS.expire)
      namespaced_history.set(timestamp, attack_info)
      # Call worker
      #Resque.enqueue(JobVipRequest,payload,originid)
      status 200
      attack_info.to_json
    end

    get "/ddos/verify" do
      current = []
      events = 0
      pattern = Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      events = current.length

      if events == 0
        status 200
        body({status: 'cleared', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else
        attacks = current.sort { |a,b| a[:ip] <=> b[:ip] }
        group_attacks = attacks.group_by { |x| x[:ip] }
        brief = []
        group_attacks.each do |k,v|
          target = k
          amount = v.length
          brief << {target: target, amount: amount}
        end
        group_attacks.to_json
      end
    end

    get "/ddos/verify/brief/?" do
      current = []
      events = 0
      pattern = Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      events = current.length

      if events == 0
        status 200
        body({status: 'cleared', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json + "\n")
      else
        attacks = current.sort { |a,b| a[:ip] <=> b[:ip] }
        group_attacks = attacks.group_by { |x| x[:ip] }
        brief = []
        group_attacks.each do |k,v|
          target = k
          amount = v.length
          brief << {target: target, amount: amount}
        end
        brief.to_json
      end
    end

    get "/ddos/status/?" do
      current = []
      brief = [] 
      pattern = Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      events = current.length

      if events == 0
        status 200
        body({status: 'cleared', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json + "\n")
      else
        attacks = current.sort { |a,b| a[:ip] <=> b[:ip] }
        group_attacks = attacks.group_by { |x| x[:ip] }
        group_attacks.each do |k,v|
          target = k
          amount = v.length
          brief << {target: target, amount: amount}
        end
        warning = []
        ddos = []
        brief.each do |item|
          warning << item if item[:amount] >= AppConfig::THRESHOLDS.warning
          ddos << item if item[:amount] >= AppConfig::THRESHOLDS.possible_ddos
        end
        if ddos.length == 0 && warning.length != 0
          body({status: 'warning', details: warning, timestamp: Time.now.strftime("%Y%m%d-%H%M%S")}.to_json)
        elsif ddos.length == 0 && warning.length == 0
          body({status: 'cleared', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
        else
          output = []
          ddos.each do |item|
            target = item[:target]
            details = group_attacks[target]
            status = 'ongoing'
            output << { target: target, status: status, details: details }
          end
        {status: 'possible_ddos', info: output, timestamp: Time.now.strftime("%Y%m%d-%H%M%S")}.to_json
        end
      end
    end
  end

end
