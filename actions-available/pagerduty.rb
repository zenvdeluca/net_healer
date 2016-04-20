require 'pagerduty'

$lastpd = Time.now - 301

class Actions
  @@pagerduty_enabled = true
  @@site = AppConfig::NOTIFICATIONS.location.upcase
  @@pagerduty = Pagerduty.new(AppConfig::PAGERDUTY.key)
  
  def warning_pagerduty(current)
    info = current[:status].upcase
    current[:target].map {|k,v| info = info + " #{k} "}
    if (Time.now - $lastpd) > 300 || (info != @@lastpdinfo)
      $lastpd = Time.now
      @@lastpdinfo = info
      incident = @@pagerduty.trigger("#{@@site.upcase} - DDoS #{info}") 
      puts "|Pagerduty_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Pagerduty_Sleep| - #{Time.now}"
    return 'sleep'
  end

  def critical_pagerduty(current)
    info = current[:status].upcase
    current[:target].map {|k,v| info = info + " #{k} "}
    if (Time.now - $lastpd) > 300 || (info != @@lastpdinfo)
      $lastpd = Time.now
      @@lastpdinfo = info
      incident = @@pagerduty.trigger("#{@@site.upcase} - DDoS #{info}") 
      puts "|Pagerduty_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Pagerduty_Sleep| - #{Time.now}"
    return 'sleep'
  end
end
