require 'pathname'

module AppConfig

  class NETHEALER
    @server = ENV['NETHEALER_SERVER']
    @influxdb = ENV['NETHEALER_INFLUXDB']
    @username = ENV['NETHEALER_USERNAME']
    @password = ENV['NETHEALER_PASSWORD']
    @whitelist = ENV['NETHEALER_WHITELIST'].nil? ? '' : ENV['NETHEALER_WHITELIST'].split(',')
    @allow_cmds = ENV['NETHEALER_ALLOW_CMDS'].nil? ? '' : ENV['NETHEALER_ALLOW_CMDS'].split(',')
    @allow_users = ENV['NETHEALER_ALLOW_USERS'].nil? ? '' : ENV['NETHEALER_ALLOW_USERS'].split(',')
    @netportal = ENV['NETPORTAL_URL']

    %i[@server].each do |config_var|
      raise "NETHEALER misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :server, :influxdb, :username, :password, :whitelist, :allow_cmds, :allow_users, :netportal
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
    @location = ENV['NOTIFICATION_LOCATION']

    %i[@smtp @smtp_from @smtp_to @location].each do |config_var|
      raise "NOTIFICATION misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :smtp, :smtp_from, :smtp_to, :location
    end
  end

  class PAGERDUTY
    @key = ENV['PAGERDUTY_KEY']

    class << self
      attr_reader :key
    end
  end


  class FLOWDOCK
    @tokens = ENV['FLOWDOCK_TOKENS'].nil? ? nil : ENV['FLOWDOCK_TOKENS'].split(',')
    
    
    class << self
      attr_reader :tokens
    end
  end

  class GRAFANA
    @url = ENV['GRAFANA_URL']

    class << self
      attr_reader :url
    end
  end

end