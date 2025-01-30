# Script that scheduled by CRON that constantly checks DNS resolving mechanism in your system and automatically configure it

Sometimes this script is necessary in order to automatically control DNS configs of the machine and return correct (e.g. you provider or user changes it manually or without your privity)

## Prerequisites:

- Debian or Debian-like OS
- Sudo permissions to execute it

## What does it do

- Checks what type of DNS resolver is used in your system
- Applies DNS IPs in system (preliminary you should give in a script file)
- Constantly checks DNS config by cron (automatically will create entry in crontab for the first use)
- Checks pinging remote host (if not, retries)

## How-to

Open file `nano autodns.sh`
Check what DNS IPs you would like to use
Make it ~great again~ executable: `chmod +x dns_checker.sh`
Execute: `./autodns.sh` or `sudo bash ./autodns.sh`
