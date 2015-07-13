
require 'pathname'

module Config

  class THRESHOLDS
    @expire = ENV['THRESHOLD_EXPIRE']         # interval in seconds to consider a current attack notify 
    @warning = ENV['THRESHOLD_WARNING']          # amount of alerts need to trigger Warning state (per IP destination)
    @possible_ddos = ENV['THRESHOLD_POSSIBLE_DDOS']    # amount of alerts need to trigger Possible DDoS state (per IP destination)
    %i[@expire @warning @possible_ddos].each do |config|
      raise "JIRA misconfiguration - no #{config}" if instance_variable_get(config).nil?
    end
    class << self
      attr_reader :warning, :possible_ddos, :expire
    end
  end

  class JIRA
    @host = ENV['JIRA_HOSTNAME']
    @user = ENV['JIRA_USER']
    @password = ENV['JIRA_PASSWORD']
    %i[@host @user @password].each do |config|
      raise "JIRA misconfiguration - no #{config}" if instance_variable_get(config).nil?
    end
    class << self
      attr_reader :host, :user, :password
    end
  end

  class FLOWDOCK
    @ops_flow = ENV['FLOWDOCK_OPS']
    @netops_notifications_flow = ENV['FLOWDOCK_NETOPS']
    %i[@ops_flow @netops_notifications_flow].each do |config|
      raise "Flowdock misconfiguration - no #{config}" if instance_variable_get(config).nil?
    end
    class << self
      attr_reader :ops_flow, :netops_notifications_flow
    end
  end
end
