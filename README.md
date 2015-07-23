# NET HEALER 
###centralizes DDoS alarms from multiple collectors, taking different stages decisions based on configured thresholds.

NET HEALER collects FastNetMon and Plixer Scrutinizer DDoS attack reports.
It group and further analyzes for taking decisions based on pre-configured protocol thresholds.

It works on four different stages 
- cleared
- warning
- critical
- under_attack

It will support actions / stage:
 - email
 - flowdock / slack / pagerduty notifications
 - execute a script

## Requirement
- Redis database
- FastNetMon: a super cool tool written by Pavel Odintsov - https://github.com/FastVPSEestiOu/fastnetmon
- Plixer Scrutinizer (optional)

##Starting up

1. `script/bootstrap`
2. Populate `.env` with a config
3. `script/start`

<br>
##Available functions

### query
GET /healer/v1/ddos/status => query DDoS status

GET /healer/v1/ddos/reports => query DDoS alarms details

GET /healer/v1/ddos/brief => query DDoS alarms brief

### WORK IN PROGRESS. PRs are more than welcome !
