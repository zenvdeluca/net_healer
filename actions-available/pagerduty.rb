require 'pagerduty'

$lastpd = Time.now - 301
$lastinfo = ''

class Actions

  @@pagerduty = Pagerduty.new(AppConfig::PAGERDUTY.key)

  def warning_pagerduty(current)
    info = current[:status].upcase
    current[:target].map {|k,v| info = info + " #{k} "}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      incident = @@pagerduty.trigger("#{@@site} - DDoS #{info}") 
      puts "|Pagerduty_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Pagerduty_Sleep| - #{Time.now}"
    return 'sleep'
  end

  def critical_pagerduty(current)
    info = current[:status].upcase
    current[:target].map {|k,v| info = info + " #{k} "}
    if (Time.now - $lastpd) > 300 || (info != $lastinfo)
      $lastpd = Time.now
      $lastinfo = info
      incident = @@pagerduty.trigger("#{@@site} - DDoS #{info}") 
      puts "|Pagerduty_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Pagerduty_Sleep| - #{Time.now}"
    return 'sleep'
  end
end
