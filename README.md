# NET HEALER 

NET HEALER centralizes DDoS Attack Reports from multiple collectors and provides tools for Analyze, Classify, Notify and Trigger Mitigation techniques.

It supports FastNetMon and Plixer Scrutinizer DDoS attack reports.<br>
Works grouping them to be used as input algorithms optimized for decision making.<br>
i.e: Target IP have traffic,pps or flow numbers >= threshold<br>
 - after 1 minutes, enter a Warning state: Notify
 - after 3 minutes, enter a critical state: Notify + Group all received info,packet and flow dumps and run decision algorithms
 - based on pre-defined policies, if under_attack: Notify + BAN IP, run a script, or activate cloud mitigation services.

## NET HEALER Stages
- cleared - no Attack Reports
- warning - a few Attack Report(s) received
- critical - Notify and run attack classification algorithms for further inspection
- under_attack - Notify and enable DDoS mitigation

## Actions / Stages
 - email
 - flowdock / slack / pagerduty notifications
 - execute a script

## Requirements
- Redis (https://github.com/antirez/redis)
- FastNetMon: a super cool tool written by Pavel Odintsov - https://github.com/FastVPSEestiOu/fastnetmon
- Plixer Scrutinizer (optional)

##Installation
0. FastNetMon should be configured to use Redis (https://github.com/FastVPSEestiOu/fastnetmon/blob/master/docs/REDIS.md)
1. install ruby (https://www.ruby-lang.org/en/documentation/installation/)
2. `$ gem install bundler`
3. `$ bundle install`
4. `$ bundle exec script/bootstrap`
5. Populate `.env` with a config
6. `$ bundle exec script/start`


##Available functions
WIP

### query
GET /healer/v1/ddos/status => query DDoS status

GET /healer/v1/ddos/reports => query DDoS alarms details

GET /healer/v1/ddos/brief => query DDoS alarms brief

### WORK IN PROGRESS.

PRs are more than welcome !
