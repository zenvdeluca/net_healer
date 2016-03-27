
class Actions
  def warning_pagerduty(current)
    pagerduty = Pagerduty.new(AppConfig::PAGERDUTY.key)
    info = current[:status] + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    incident = pagerduty.trigger("#{AppConfig::NOTIFICATIONS.location} - DDOS CRITICAL: #{info}")
    puts "|Pagerduty_Sent| - #{Time.now}"
    return true
  end
end
