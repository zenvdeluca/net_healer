require 'redis'
require 'redis-namespace'
require 'uri'

class Healer
  redis_server=AppConfig::NETHEALER.server
  redis_connection = Redis.new(:host => redis_server)
  namespaced_current = Redis::Namespace.new('healer_current', redis: redis_connection)
  namespaced_history = Redis::Namespace.new('healer_history', redis: redis_connection)

  def report_initializer(queue)
    if queue.empty?
      return false
    end
    return queue.group_by {|report| report[:information]['ip']}
  end


  namespace API_URL do

    get "/ddos/reports/?:p1?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      reports = report_initializer(current)

      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else

      aggregate = {} 
      reports.each do |k,v|
        aggregate["#{k}"] = {}
        aggregate["#{k}"]['detected'] = 0
        aggregate["#{k}"]['protocol'] = []
        aggregate["#{k}"]['incoming'] = {}

        aggregate["#{k}"]['incoming']['total'] = {}
        aggregate["#{k}"]['incoming']['total']['traffic'] = 0
        aggregate["#{k}"]['incoming']['total']['pps'] = 0
        aggregate["#{k}"]['incoming']['total']['flows'] = 0

        aggregate["#{k}"]['incoming']['tcp'] = {}
        aggregate["#{k}"]['incoming']['tcp']['traffic'] = 0
        aggregate["#{k}"]['incoming']['tcp']['pps'] = 0
        aggregate["#{k}"]['incoming']['tcp']['syn'] = {}
        aggregate["#{k}"]['incoming']['tcp']['syn']['traffic'] = 0
        aggregate["#{k}"]['incoming']['tcp']['syn']['pps'] = 0

        aggregate["#{k}"]['incoming']['udp'] = {}
        aggregate["#{k}"]['incoming']['udp']['traffic'] = 0
        aggregate["#{k}"]['incoming']['udp']['pps'] = 0
      
        aggregate["#{k}"]['incoming']['icmp'] = {}
        aggregate["#{k}"]['incoming']['icmp']['traffic'] = 0
        aggregate["#{k}"]['incoming']['icmp']['pps'] = 0

        aggregate["#{k}"]['capture'] = [] if params[:p1] == 'capture'


      
       

        reports["#{k}"].each do |item|
          aggregate["#{k}"]['detected'] += 1
          aggregate["#{k}"]['attack_type'] = 'unknown' && item[:information]['attack_details']['attack_type']
          aggregate["#{k}"]['direction'] = item[:information]['attack_details']['attack_direction']
          aggregate["#{k}"]['protocol'] = aggregate["#{k}"]['protocol'] | [item[:information]['attack_details']['attack_protocol']]
        
          aggregate["#{k}"]['incoming']['total']['traffic'] = [aggregate["#{k}"]['incoming']['total']['traffic'],item[:information]['attack_details']['total_incoming_traffic']].max
          aggregate["#{k}"]['incoming']['total']['pps'] = [aggregate["#{k}"]['incoming']['total']['pps'],item[:information]['attack_details']['total_incoming_pps']].max
          aggregate["#{k}"]['incoming']['total']['flows'] = [aggregate["#{k}"]['incoming']['total']['flows'],item[:information]['attack_details']['total_incoming_flows']].max
        

          aggregate["#{k}"]['incoming']['tcp']['traffic'] = [aggregate["#{k}"]['incoming']['tcp']['traffic'],item[:information]['attack_details']['incoming_tcp_traffic']].max
          aggregate["#{k}"]['incoming']['tcp']['pps'] = [aggregate["#{k}"]['incoming']['tcp']['pps'],item[:information]['attack_details']['incoming_tcp_pps']].max
          aggregate["#{k}"]['incoming']['tcp']['syn']['traffic'] = [aggregate["#{k}"]['incoming']['tcp']['syn']['traffic'],item[:information]['attack_details']['incoming_syn_tcp_traffic']].max
          aggregate["#{k}"]['incoming']['tcp']['syn']['pps'] = [aggregate["#{k}"]['incoming']['tcp']['syn']['pps'],item[:information]['attack_details']['incoming_syn_tcp_pps']].max
          
          aggregate["#{k}"]['incoming']['udp']['traffic'] = [aggregate["#{k}"]['incoming']['udp']['traffic'],item[:information]['attack_details']['incoming_udp_traffic']].max
          aggregate["#{k}"]['incoming']['udp']['pps'] = [aggregate["#{k}"]['incoming']['udp']['pps'],item[:information]['attack_details']['incoming_udp_pps']].max
          
          aggregate["#{k}"]['incoming']['icmp']['traffic'] = [aggregate["#{k}"]['incoming']['icmp']['traffic'],item[:information]['attack_details']['incoming_icmp_traffic']].max
          aggregate["#{k}"]['incoming']['icmp']['pps'] = [aggregate["#{k}"]['incoming']['icmp']['pps'],item[:information]['attack_details']['incoming_icmp_pps']].max

          item[:packets_dump].each { |pcap_line| aggregate["#{k}"]['capture'] << pcap_line } if params[:p1] == 'capture'

        end
      end

      # normalize bps => mbps

      aggregate.each do |k,v|
        aggregate["#{k}"]['incoming']['total']['traffic'] = (aggregate["#{k}"]['incoming']['total']['traffic'] / 1048576.0).round(2)
        aggregate["#{k}"]['incoming']['tcp']['traffic'] = (aggregate["#{k}"]['incoming']['tcp']['traffic'] / 1048576.0).round(2)
        aggregate["#{k}"]['incoming']['udp']['traffic'] = (aggregate["#{k}"]['incoming']['udp']['traffic'] / 1048576.0).round(2)
        aggregate["#{k}"]['incoming']['icmp']['traffic'] = (aggregate["#{k}"]['incoming']['icmp']['traffic'] / 1048576.0).round(2)
      end
      
        body({reports: aggregate, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      end
    end

    get "/ddos/brief/?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
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
      current = []
      warning = {}
      critical = {}

      pattern = '*' + Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      reports = report_initializer(current)
      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else
        summary = reports.map { |k,v| { "#{k}" => v.length } }
        brief = summary.reduce Hash.new, :merge
        brief.each do |k,v|
          warning[k] = v if v >= AppConfig::THRESHOLDS.warning
          critical[k] = v if v >= AppConfig::THRESHOLDS.critical
        end

        return body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json) if warning.empty? && critical.empty?
        return body({status: 'warning', target: warning, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json) if critical.empty?
        return body({status: 'critical', target: critical, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      end

    end

  end
end
