# Script for automatic MediaWiki installation with PHP, NGINX, MariaDB

Used to install on a variety of hosts in any automated procedures or just on one machine to simplify the process

## Prerequisites

- Any Debian-like OS (Debian, Ubuntu, Mint, ...) because uses APT manager
- Knowing what versions of MediaWiki, PHP, NGINX you want to install (just check [MediaWiki reqs](https://www.mediawiki.org/wiki/Manual:Installation_requirements) )

## How to

- Save files to any folder on a machine
- Make them executable `chmod +x *.sh`
- Open in nano (or vim or mcedit or ... any you like) and change parameters on first lines `nano 1.MariaDB_install.sh`:

```bash
DB_ROOT_PASSWORD="ChangeMe" #ROOT password of DB to create all other stuff
DB_MEDIAWIKI_USER="mediawiki" #User of Mediawiki to be created in DB
DB_MEDIAWIKI_PASSWORD="MEDIAWIKI" #Password of user of Mediawiki to be created in DB
DB_MEDIAWIKI_HOST="192.168.11.10" #IP where DB is located
LOG_FILE="/tmp/mariadb_install.log" #Log for this script

```
Then `nano 2. PHP+NGINX+Mediawiki_install.sh`:

```bash
NGINX_CONF="/etc/nginx/sites-available/mediawiki"
MEDIAWIKI_DIR="/var/www/html/mediawiki"
MEDIAWIKI_VER="1.39.5"
PHP_VERSION="8.1" # Last version of PHP supported by MediaWiki, check its requirements page
DB_HOST="192.168.11.11" #Where database should be located
DB_NAME="mediawiki_db" #DB name for MediWiki engine
DB_USER="wiki_user" #Username for Mediawiki user of DB
DB_PASSWORD="your_password" #Password
LOCAL_IP="192.168.11.10" #IP for machine where Mediawiki is located (could be the same for DB host or different)
LOG_FILE="/tmp/install.log" #Log path for script
```
Could be combined in one file if you want or if DB is located on the same host with others

- Execute first to install MariaDB, second - others:
```bash
./1.*.sh
```
Then:
```bash
./2.*.sh
```

You should have sudo to execute and install properly
