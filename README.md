# NE(a)T HEALER 
###provides you a central database for handling and storing DDoS alarms, allowing you to automatically take decisions based on thresholds.

HEALER currently support alarm input by FastNetMon and Plixer Scrutinizer devices.

##Starting up

1. `script/bootstrap`
2. Populate `.env` with a config
3. `script/start`

<br>
##Available functions and examples:

/healer/v1/ddos/status => query DDoS status (clear/warning/possible DDoS)

/healer/v1/ddos/verify => query current DDoS information in details

/healer/v1/ddos/verify/brief => query current DDoS brief information
