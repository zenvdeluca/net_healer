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
    grouped = queue.group_by {|report| report[:information]['ip']}
    
    report = {}
    puts grouped.to_json  
    grouped[:reports].each do |item|
      ip = item[:information]['ip']
      report["#{ip}"] = {}
      report["#{ip}"]['site'] = item['site']
    end
    report

  end


  namespace API_URL do

    get "/ddos/reports/?" do
      current = []
      pattern = '*' + Time.now.strftime("%Y") + '*'
      namespaced_current.scan_each(:match => pattern) {|key| current << eval(namespaced_current.get(key)) }
      reports = report_initializer(current)
      unless reports
        body({status: 'clear', timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
      else
        body({reports: reports, timestamp: Time.now.strftime("%Y%m%d-%H%M%S") }.to_json)
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
