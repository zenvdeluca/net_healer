require 'net/smtp'
require 'yaml'

$lastemail = Time.now - 301
$lastinfo = ''

class Actions
  def warning_email(current)
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastemail) > 300 || (info != $lastinfo)
      $lastemail = Time.now
      $lastinfo = info
      currentrep = [] ; pattern = '*' + Time.now.strftime("%Y") + '*'
      $namespaced_current.scan_each(:match => pattern) {|key| currentrep << eval($namespaced_current.get(key)) }
      reports = report_initializer(currentrep)
      aggregate = report_aggregate(reports)
      message = <<MESSAGE_END
From: Net Healer (DDoS) <#{AppConfig::NOTIFICATIONS.smtp_from}>
To: Network Operations <#{AppConfig::NOTIFICATIONS.smtp_to}>
Subject: [WARNING] - Possible DDoS in #{AppConfig::NOTIFICATIONS.location} - target: #{info}

Healer Dashboard: https://netmonitor.zdsys.com

Attack info:
#{aggregate.to_yaml}

MESSAGE_END

      Net::SMTP.start(AppConfig::NOTIFICATIONS.smtp) do |smtp|
        smtp.send_message message, AppConfig::NOTIFICATIONS.smtp_from,AppConfig::NOTIFICATIONS.smtp_to
      end

      puts "|Email_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Email_Sleep| - #{Time.now}"
    return 'sleep'
  end

  def critical_email(current)
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    if (Time.now - $lastemail) > 300 || (info != $lastinfo)
      $lastemail = Time.now
      $lastinfo = info
      currentrep = [] ; pattern = '*' + Time.now.strftime("%Y") + '*'
      $namespaced_current.scan_each(:match => pattern) {|key| currentrep << eval($namespaced_current.get(key)) }
      reports = report_initializer(currentrep)
      aggregate = report_aggregate(reports)
      message = <<MESSAGE_END
From: Net Healer (DDoS) <#{AppConfig::NOTIFICATIONS.smtp_from}>
To: Network Operations <#{AppConfig::NOTIFICATIONS.smtp_to}>
Subject: [CRITICAL] - Possible DDoS in #{AppConfig::NOTIFICATIONS.location} - target: #{info}

Healer Dashboard: https://netmonitor.zdsys.com

Attack info:
#{aggregate.to_yaml}

MESSAGE_END

      Net::SMTP.start(AppConfig::NOTIFICATIONS.smtp) do |smtp|
        smtp.send_message message, AppConfig::NOTIFICATIONS.smtp_from,AppConfig::NOTIFICATIONS.smtp_to
      end

      puts "|Email_Sent| - #{Time.now}"
      return 'sent'
    end
    puts "|Email_Sleep| - #{Time.now}"
    return 'sleep'
  end

end
