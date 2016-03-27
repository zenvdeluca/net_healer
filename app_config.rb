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
    @location = ENV['NOTIFICATION_LOCATION']

    %i[@location].each do |config_var|
      raise "NOTIFICATION misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :location
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
