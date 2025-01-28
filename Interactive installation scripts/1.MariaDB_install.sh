#!/bin/bash

## MariaDB installation script on a separate host

# Configurations
DB_ROOT_PASSWORD="ChangeMe" #ROOT password of DB to create all other stuff
DB_MEDIAWIKI_USER="mediawiki" #User of Mediawiki to be created in DB
DB_MEDIAWIKI_PASSWORD="MEDIAWIKI" #Password of user of Mediawiki to be created in DB
DB_MEDIAWIKI_HOST="192.168.11.10" #IP where DB is located
LOG_FILE="/tmp/mariadb_install.log" #Log for this script

# Logging
exec > >(tee -a $LOG_FILE) 2>&1

# Packages update
echo "Updating pacakages"
sudo apt update || { echo "Error during update packages... Is network up?"; exit 1; }

# Установка MariaDB
echo "Installing MariaDB..."
sudo apt install -y mariadb-server || { echo "Error installing MariaDB"; exit 1; }

# Restart MariaDB
echo "Restarting MariaDB..."
sudo systemctl restart mariadb || { echo "Error during MariaDB restart"; exit 1; }

# Paasing MariaDB starting question
echo "Configuring MariaDB (removing anonymous users, canceling root remote access)..."
sudo mysql_secure_installation <<EOF

y
$DB_ROOT_PASSWORD
$DB_ROOT_PASSWORD
y
y
y
y
EOF

# Настройка root пользователя
echo "Root user config..."
sudo mysql -u root -p$DB_ROOT_PASSWORD -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD'; FLUSH PRIVILEGES;" || { echo "Error during root user creation"; exit 1; }

# Creating user for MediaWiki
echo "Creating user for MediaWiki..."
sudo mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER '$DB_MEDIAWIKI_USER'@'$DB_MEDIAWIKI_HOST' IDENTIFIED BY '$DB_MEDIAWIKI_PASSWORD';" || { echo "Error creating mediawiki user"; exit 1; }
sudo mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '$DB_MEDIAWIKI_USER'@'$DB_MEDIAWIKI_HOST' WITH GRANT OPTION;" || { echo "Error grant permissions for mediawiki user"; exit 1; }
sudo mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;" || { echo "Error activating permissions"; exit 1; }

# Configurating remote MariaDB connecting
echo "Configurating remote MariaDB connecting..."
sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf || { echo "Error during bind-address configuration"; exit 1; }

# Reloading
echo "Reloading MariaDB..."
sudo systemctl restart mariadb || { echo "Error restarting MariaDB"; exit 1; }

# Success
echo "Installtion of MariaDB is complete."