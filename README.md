# NET HEALER 

NET HEALER receive DDoS Attack reports from FastNetMon collectors allowing different triggering on a per stage (warning/critical/under_attack) based actions.
Allows integration with non gaussian algorithms for anomaly detection.<br>
Provides a RESTful like API

## NET HEALER Stages example
- clear - no Attack Reports received for any /32 target
- warning - less or equal to 2 Attack Reports received for /32 target(s)
- critical - more than 2 Attack Reports received for /32 target(s)
- under_attack - FastNetMon + anomaly detected

Each 1 FNM /32 ban = 1 NET HEALER Attack Report<br>
Lower the FNM ban time, faster NET HEALER will advance in stages (thresholds can be customized)<br>
Start with FNM ban time: 45 seconds (NET HEALER will converge from cleared to warning after 90 seconds)

## Actions
Working:
 - Grafana vertical bars markdown including state/target
 - Email
 - Pagerduty
 - Flowdock messages
 - BGP announces (BIRD + kernel blackhole tables)

## Requirements
- FastNetMon: a super cool tool written by Pavel Odintsov - https://github.com/FastVPSEestiOu/fastnetmon
- Redis (https://github.com/antirez/redis)
## Nice to have
- InfluxDB (https://github.com/influxdb/influxdb)
- Grafana (https://github.com/grafana/grafana)
- Morgoth (https://github.com/nathanielc/morgoth)

##Installation
0. FastNetMon (FNM) should be configured to use:
 - Redis (https://github.com/FastVPSEestiOu/fastnetmon/blob/master/docs/REDIS.md)
 - InfluxDB (https://github.com/FastVPSEestiOu/fastnetmon/blob/master/docs/INFLUXDB_INTEGRATION.md)
 - Add to /usr/local/bin/notify_about_attack.sh under if [ "$4" == "attack_details" ]; then
    <br>curl -sk https://{nethealer_ip:port}/healer/v1/ddos/pool
    <br>curl -sk https://{nethealer_ip:port}/healer/v1/ddos/actions


1. install ruby (https://www.ruby-lang.org/en/documentation/installation/)
2. `$ gem install bundler`
3. `$ bundle install`
4. `$ bundle exec script/bootstrap`
5. Populate `.env` with a config
6. `$ bundle exec script/start`

## Screenshot during an attack
![alt tag](https://raw.githubusercontent.com/zenvdeluca/net_healer/master/extra/nethealer.png)

##How to query the API

### GET /healer/v1/ddos/status
```
{
  "status": "clear",
  "timestamp": "20150913-115403"
}
```

### GET /healer/v1/ddos/reports

```json
{
    "reports": {
        "200.200.200.10": {
            "fqdn": "nethealer.hostingxpto.com",
            "attack_type": "udp_flood",
            "alerts": 2,
            "protocol": [
                "udp"
            ],
            "incoming": {
                "total": {
                    "mbps": 2894.96,
                    "pps": 781380,
                    "flows": 628
                },
                "tcp": {
                    "mbps": 1.71,
                    "pps": 2654,
                    "syn": {
                        "mbps": 0.08,
                        "pps": 109
                    }
                },
                "udp": {
                    "mbps": 2761,
                    "pps": 779884
                },
                "icmp": {
                    "mbps": 0,
                    "pps": 0
                }
            }
        }
    }
}

### GET /healer/v1/ddos/brief 
=> query /32 targets + amount of current Attack Reports
```json
{
  "reports": {
    "200.200.200.10": 3,
  },
  "timestamp": "20150913-030255"
}
```

### WORK IN PROGRESS
=> PRs are more than welcome !

### Need help ?
send me an email vdeluca@zendesk.com
