require 'pathname'

module AppConfig

  class THRESHOLDS
    @expire = ENV['THRESHOLD_EXPIRE'].to_i                # interval in seconds to consider a current attack notify
    @warning = ENV['THRESHOLD_WARNING'].to_i              # amount of alerts need to trigger Warning state (per IP destination)
    @possible_ddos = ENV['THRESHOLD_POSSIBLE_DDOS'].to_i  # amount of alerts need to trigger Possible DDoS state (per IP destination)
    @action = ENV['THRESHOLD_ACTION']

    %i[@expire @warning @possible_ddos @action].each do |config_var|
      raise "THRESHOLDS misconfiguration - no #{config_var}" if instance_variable_get(config_var).nil?
    end
    class << self
      attr_reader :warning, :possible_ddos, :expire, :action
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
