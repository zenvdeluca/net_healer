require 'pathname'

module AppConfig

  class NETHEALER
    @server = ENV['NETHEALER_SERVER']
    @influxdb = ENV['NETHEALER_INFLUXDB']
    @username = ENV['NETHEALER_USERNAME']
    @password = ENV['NETHEALER_PASSWORD']

    %i[@server].each do |config_var|
      raise "NETHEALER misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :server, :influxdb, :username, :password
    end
  end

  class THRESHOLDS
    @expire = ENV['THRESHOLD_EXPIRE'].to_i
    @warning = ENV['THRESHOLD_WARNING'].to_i
    @critical = ENV['THRESHOLD_CRITICAL'].to_i

    %i[@expire @warning @critical].each do |config_var|
      raise "THRESHOLDS misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :warning, :critical, :expire
    end
  end

  class NOTIFICATIONS
    @smtp = ENV['NOTIFICATION_EMAIL_SMTP']
    @smtp_from = ENV['NOTIFICATION_EMAIL_FROM']
    @smtp_to = ENV['NOTIFICATION_EMAIL_TO']

    %i[@smtp @smtp_from @smtp_to].each do |config_var|
      raise "NOTIFICATION misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :smtp, :smtp_from, :smtp_to
    end
  end

  class PAGERDUTY
    @key = ENV['PAGERDUTY_KEY']

    class << self
      attr_reader :key
    end
  end


  class FLOWDOCK
    @ops_flow = ENV['FLOWDOCK_OPS']
    @netops_notifications_flow = ENV['FLOWDOCK_NETOPS']

    class << self
      attr_reader :ops_flow, :netops_notifications_flow
    end
  end
end
