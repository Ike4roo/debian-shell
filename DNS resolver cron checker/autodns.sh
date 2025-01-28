#!/bin/bash

# Please change next lines with what you want
# DNS-servers
DNS_SERVERS=("77.88.8.8" "8.8.8.8" "192.168.10.1" "192.168.15.1")
DNS_CONFIG_FILE="/etc/resolv.conf"
AUTODNS_SCRIPT="/etc/scripts/autodns.sh"
PING_CHECK=("ya.ru" "google.com" "192.168.10.1" "192.168.15.1")



## Don not change after these lines if you dont know what is it for
# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------


# Check for root privileges
if [ "$EUID" -ne 0 ]; then
echo "Usage: sudo $0"
exit 1
fi

backup_file() {
local config_file="$1"
local timestamp=$(date +%Y%m%d%H%M%S)
local backup_file="${config_file}.backup.${timestamp}"

if [ ! -f "$backup_file" ]; then
 cp "$config_file" "$backup_file"
 echo "Backup created: $backup_file"
fi
}

update_dns_config() {
backup_file "$DNS_CONFIG_FILE"
echo "# Auto config of DNS" > "$DNS_CONFIG_FILE"
for server in "${DNS_SERVERS[@]}"; do
 echo "nameserver $server" >> "$DNS_CONFIG_FILE"
done
echo "DNS configuration updated."
}

install_dns_client() {
if ! command -v resolvconf >/dev/null && ! command -v dhclient >/dev/null && ! systemctl is-active --quiet systemd-resolved; then
 echo "No DNS client installed. Installing resolvconf."
 apt update && apt install -y resolvconf
fi
}

ping_test() {
for target in "${PING_CHECK[@]}"; do
 if ! ping -c 4 "$target" &>/dev/null; then
   echo "Ping failed for $target"
   return 1
 fi
done
echo "All ping tests passed."
return 0
}

# Automatic script creation

restart_dns_client() {
systemctl restart systemd-resolved 2>/dev/null && echo "systemd-resolved restarted."
}

create_autodns_script() {
mkdir -p /etc/scripts
cat << EOF > "$AUTODNS_SCRIPT"
#!/bin/bash
DNS_SERVERS=(${DNS_SERVERS[*]})
PING_CHECK=(${PING_CHECK[*]})
DNS_CONFIG_FILE="$DNS_CONFIG_FILE"

ping_test() {
for target in "\${PING_CHECK[@]}"; do
 if ! ping -c 4 "\$target" &>/dev/null; then
   echo "Ping failed for \$target"
   return 1
 fi
done
return 0
}

update_dns_config() {
echo "# Auto config of DNS" > "\$DNS_CONFIG_FILE"
for server in "\${DNS_SERVERS[@]}"; do
 echo "nameserver \$server" >> "\$DNS_CONFIG_FILE"
done
echo "DNS configuration updated."
}

retry_ping_and_update() {
for i in {1..5}; do
 if ping_test; then
   exit 0
 fi
 sleep 300
done
update_dns_config
systemctl restart systemd-resolved
}

retry_ping_and_update
EOF
chmod +x "$AUTODNS_SCRIPT"
}

# Cron question
setup_cron_check() {
read -rp "Add cron schedule for autodns.sh (00:00, 12:00)? [y/n]: " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
 create_autodns_script
 (crontab -l 2>/dev/null; echo "0 0,12 * * * $AUTODNS_SCRIPT") | crontab -
 echo "Cron schedule added."
fi
}

main() {
install_dns_client
update_dns_config
restart_dns_client

if ! ping_test; then
 echo "Ping failed. Retrying in 3 minutes."
 sleep 180
 if ! ping_test; then
   echo "Ping failed again. Check manually."
 fi
fi
}

# Main body of script
main

# Func of cron
setup_cron_check