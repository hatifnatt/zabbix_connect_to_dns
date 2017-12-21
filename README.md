# What is it
By default, auto-registred hosts added with "Connect to IP", but in case machine doesn't have fixed IP (DHCP) this behaviour can be a problem. More details can be found in feature request [ZBXNEXT-1740](https://support.zabbix.com/browse/ZBXNEXT-1740). This script have been created to solve this problem, it can be added as ["Remote command"](https://www.zabbix.com/documentation/3.4/manual/config/notifications/action/operation/remote_command) and it will automatically switch "Connect to" to DNS, optionally it can remove IP address completely from host config.
## How it work
Script make queries directly to Zabbix database (MySQL only). Although Zabbix API is preferable solution.
## Installation
First of all you must put script somewhere at your Zabbix server in `/usr/bin` for example.
##### wget
```
wget -O /usr/bin/zabbix_connect_to_dns.sh https://raw.githubusercontent.com/hatifnatt/zabbix_connect_to_dns/master/zabbix_connect_to_dns.sh
chmod a+x /usr/bin/zabbix_connect_to_dns.sh
```
##### curl
```
curl https://raw.githubusercontent.com/hatifnatt/zabbix_connect_to_dns/master/zabbix_connect_to_dns.sh > /usr/bin/zabbix_connect_to_dns.sh
chmod a+x /usr/bin/zabbix_connect_to_dns.sh
```
##### git
```
git clone https://github.com/hatifnatt/zabbix_connect_to_dns.git
cp zabbix_connect_to_dns/zabbix_connect_to_dns.sh /usr/bin/zabbix_connect_to_dns.sh
chmod a+x /usr/bin/zabbix_connect_to_dns.sh
```
You need to create new or modify your existing ["Active agent auto-registration"](https://www.zabbix.com/documentation/3.4/manual/discovery/auto_registration) action. Then you need to add new operation.
* Operation type: Remote command
* Target list: Current host
* Type: Custom script
* Execute on: Zabbix server
* Commands: `/usr/bin/zabbix_connect_to_dns.sh -n {HOST.HOST} -r`

![Addition of 'Remote command' operation in Zabbix Web](https://user-images.githubusercontent.com/807283/34272988-87d4d0d2-e6a3-11e7-9aab-54fe72aa89fb.png)

## Manual usage
Scipt can be also used in manual mode, simply run script in terminal, with `-r` key IP will be removed from host config.
* You can switch single host to DNS and remove IP from config:
  ```
  /usr/bin/zabbix_connect_to_dns.sh -n some.domain.tld -r
  ```
* Switch multiple hosts which ends in a "domain.tld"
  ```
  /usr/bin/zabbix_connect_to_dns.sh -a domain.tld
  ```
