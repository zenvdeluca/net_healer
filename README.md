# NET HEALER 
###centralizes DDoS alarms from multiple collectors, taking different stages decisions based on configured thresholds.

NET HEALER listens to FastNetMon and Plixer Scrutinizer reports.
When new reports are received, it analyzes them, taking actions based on pre-configured protocol thresholds.

It works on four different stages 
- cleared
- warning
- possible_ddos
- under_attack

You can specify different actions for each stage
 - email
 - flowdock / slack / pagerduty notifications
 - execute a script (login to routers and enable policy options)

## Requirement
- Redis database
- FastNetMon: a super cool tool written by Pavel Odintsov - https://github.com/FastVPSEestiOu/fastnetmon
- Plixer scrutinizer (optional)

##Starting up

1. `script/bootstrap`
2. Populate `.env` with a config
3. `script/start`

<br>
##Available functions

### query
GET /healer/v1/ddos/status => query DDoS status

GET /healer/v1/ddos/verify => query DDoS alarms details

GET /healer/v1/ddos/verify/brief => query DDoS alarms brief

# Post alarms
POST /healer/v1/ddos/notify => post FastNetMon alarm

# WORK IN PROGRESS. COLABORATE !
