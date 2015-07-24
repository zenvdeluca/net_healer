# NET HEALER 

NET HEALER centralizes DDoS Attack Reports from multiple collectors and provides tools for Analyzing, Classifying, Notifying and Mitigating DDoS Attacks.

NET HEALER supports FastNetMon and Plixer Scrutinizer DDoS attack reports.<br>
It will also group them to be used by other algorithms optimized for decision making.
i.e: trigger a notification or BAN an IP based on pre-configured protocol thresholds.

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
