require 'influxdb'

$influxdb_events = $influxdb_graphite = InfluxDB::Client.new 'graphite', host: AppConfig::NETHEALER.influxdb, username: AppConfig::NETHEALER.username, password: AppConfig::NETHEALER.password

class Actions
  def warning_influx_vertical_mark(current)
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    data = {
      values: { type: "WARNING", info: info.to_s, },
    }
    $influxdb_events.write_point('nethealer', data)
    puts "|InfluxDB_Warning_Mark| - #{Time.now}"
    return 'sent'
  end

  def critical_influx_vertical_mark(current)
    info = current[:status].upcase + ' '
    current[:target].map {|k,v| info = info + "|#{k}"}
    data = {
      values: { type: "CRITICAL", info: info.to_s, },
    }
    $influxdb_events.write_point('nethealer', data)
    puts "|InfluxDB_Critical_Mark| - #{Time.now}"
    return 'sent'
  end
end
