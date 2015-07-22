module ReportsParser
  class FastNetMon
    attr_reader :payload

    def initialize(payload)
      @payload = payload
    end

    def to_json
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
      attack_info
    end
  end
end
