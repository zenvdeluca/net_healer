require 'pathname'

module AppConfig

  class REDIS
    @server = ENV['REDIS_SERVER']
    @port = ENV['REDIS_PORT']
    %i[@server].each do |config_var|
      raise "REDIS misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :server, :port
    end
  end

  class THRESHOLDS
    @expire = ENV['THRESHOLD_EXPIRE'].to_i                
    @warning = ENV['THRESHOLD_WARNING'].to_i              
    @critical = ENV['THRESHOLD_CRITICAL'].to_i 
    @action = ENV['THRESHOLD_ACTION']

    %i[@expire @warning @critical @action].each do |config_var|
      raise "THRESHOLDS misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :warning, :critical, :expire, :action
    end
  end

  class JIRA
    @host = ENV['JIRA_HOSTNAME']
    @user = ENV['JIRA_USER']
    @password = ENV['JIRA_PASSWORD']

    %i[@host @user @password].each do |config_var|
      raise "JIRA misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :host, :user, :password
    end
  end

  class FLOWDOCK
    @ops_flow = ENV['FLOWDOCK_OPS']
    @netops_notifications_flow = ENV['FLOWDOCK_NETOPS']

    %i[@ops_flow @netops_notifications_flow].each do |config_var|
      raise "Flowdock misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :ops_flow, :netops_notifications_flow
    end
  end
end
