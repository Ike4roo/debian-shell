#!/bin/bash

# Semiautomatic installation script for NGINX + PHP + Mediawiki

## IPs are given as example, change them whatever you need


# Here are some params you need to give

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

# Rewrite confirmation

confirm_overwrite() {
    while true; do
        read -p "Folder $MEDIAWIKI_DIR exists. Wish to rewrite? [y/n]: " yn
        case $yn in
            [Yy]* ) sudo rm -rf $MEDIAWIKI_DIR; break;;
            [Nn]* ) echo "Operation is canceled."; exit;;
            * ) echo "Please put 'y' to let it rewrite or 'n' to cancel.";;
        esac
    done
}

# Logging

exec > >(tee -a $LOG_FILE) 2>&1

# Check RW folder status

if [ -d "$MEDIAWIKI_DIR" ]; then
    confirm_overwrite
fi

# Packages update

echo "Updating packages..."
sudo apt update || { echo "Error during packages update. Is network working?"; exit 1; }

# PHP repo

echo "Installing PHP repo..."
sudo apt install -y software-properties-common || { echo "Error during PHP repo software-properties-common installation"; exit 1; }
sudo add-apt-repository ppa:ondrej/php -y || { echo "Error during PHP repo installation"; exit 1; }
sudo apt update || { echo "Error during update PHP repo after it installation"; exit 1; }

# Installing NGINX

echo "Установка Nginx и PHP..."
sudo apt install -y nginx mariadb-client php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-intl php$PHP_VERSION-xml php$PHP_VERSION-mbstring php$PHP_VERSION-gd php$PHP_VERSION-curl unzip || { echo "Ошибка при установке Nginx и PHP"; exit 1; }

# Installing MediaWiki

echo "Installing MediaWiki..."
cd /tmp
wget https://releases.wikimedia.org/mediawiki/1.39/mediawiki-$MEDIAWIKI_VER.tar.gz || { echo "Error during download MediaWiki"; exit 1; }
tar -xvzf mediawiki-1.39.1.tar.gz || { echo "Ошибка при распаковке MediaWiki"; exit 1; }
sudo mv mediawiki-1.39.1 $MEDIAWIKI_DIR

# Check permissions

echo "Permissions check..."
sudo chown -R www-data:www-data $MEDIAWIKI_DIR || { echo "Error during owner permissions check of MediaWiki directory operation"; exit 1; }
sudo chmod -R 755 $MEDIAWIKI_DIR || { echo "Error making MediaWiki accessible to it"; exit 1; }

# Nginx configuration

if [ -f "$NGINX_CONF" ]; then
    echo "Config file $NGINX_CONF already exists. Rewriting..."
    sudo rm $NGINX_CONF
fi

sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $LOCAL_IP;

    root $MEDIAWIKI_DIR;
    index index.php index.html index.htm;

    location / {
        try_files\$uri \$uri/ /index.php?\$query_string;
    }

    location ~\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~*\.(js|css|png|jpg|jpeg|gif|ico)\$ {
        try_files \$uri /index.php?\$query_string;
        expires max;
        log_not_found off;
    }

    error_log /var/log/nginx/mediawiki_error.log;
    access_log /var/log/nginx/mediawiki_access.log;
}
EOL

# Activation Nginx

echo "Restarting Nginx..."
sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled/ || { echo "Error making symlink for Nginx config"; exit 1; }
sudo systemctl restart nginx || { echo "Error restarting Nginx Nginx"; exit 1; }

# Last message

echo "Installing complete. Please go to http://$LOCAL_IP/mediawiki in order to finish MediaWiki installation."

