#!/bin/bash

# Please change next lines with what you want
# DNS-servers
DNS_SERVERS=("77.88.8.8" "8.8.8.8" "192.168.10.1" "192.168.15.1")
DNS_CONFIG_FILE="/etc/resolv.conf"
AUTODNS_SCRIPT="/etc/scripts/autodns.sh"
PING_CHECK=("ya.ru" "google.com" "192.168.10.1" "192.168.15.1")

# Define what user is
if [ "$EUID" -ne 0 ]; then
  echo "Please use sudo to start the script"
  exit 1
fi

# Backup func
backup_file() {
  local config_file="$1"
  local backup_file="${config_file}.backup"
  
  if [ ! -f "$backup_file" ]; then
    cp "$config_file" "$backup_file"
    echo "Config backup is: $backup_file"
  fi
}

# Config file func
update_dns_config() {
  local config_file="$1"
  
  # Backuping
  backup_file "$config_file"
  
  # Clear old
  echo "Renewing DNS configs in file: $config_file"
  echo "# Auto config of DNS" > "$config_file"
  for server in "${DNS_SERVERS[@]}"; do
    echo "nameserver $server" >> "$config_file"
  done
  echo "Changes are implemented in $config_file"
}

# Checking DNS and make config if necessary
install_dns_client() {
  local client_installed=false

  if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved is used in system."
    client_installed=true
  elif command -v resolvconf >/dev/null 2>&1; then
    echo "resolvconf is used in system."
    client_installed=true
  elif command -v dhclient >/dev/null 2>&1; then
    echo "dhclient is used in system."
    client_installed=true
  fi

  if [ "$client_installed" = false ]; then
    echo "Searching DNS clients"
    available_clients=$(apt search '^resolvconf$|^systemd-resolved$|^dhclient$' 2>/dev/null | grep -E '^resolvconf|systemd-resolved|dhclient' | awk '{print $1}')

    if [ -z "$available_clients" ]; then
      echo "There is nothing found. No DNS client is in the system."
      exit 1
    fi

    echo "Avaulable DNS clients:"
    echo "$available_clients"

    echo "What DNS client do you wish to use in a system?"
    read -r selected_client

    if echo "$available_clients" | grep -q "^$selected_client$"; then
      echo "Installing $selected_client..."
      apt update && apt install -y "$selected_client"
      if command -v "$selected_client" >/dev/null 2>&1; then
        echo "$selected_client successfully installed."
      else
        echo "Cannot proceed with installation $selected_client. Try it manually: apt install $selected_client."
        exit 1
      fi
    else
      echo "This client is not accessible for installation. Try download it to machine other way, then: apt install ./$selected_client.."
      exit 1
    fi
  fi
}

# DNS Client restart
restart_dns_client() {
  if systemctl is-active --quiet systemd-resolved; then
    systemctl restart systemd-resolved
    echo "Subsystem systemd-resolved restarted."
  fi
}

# Pinging to check DNS is working
ping_test() {
  local ping_targets=($PING_CHECK)

  for target in "${ping_targets[@]}"; do
    if ! ping -c 4 "$target" > /dev/null 2>&1; then
      echo "No access to $target"
      return 1
    fi
  done
  echo "Ping successfully finished to: ${ping_targets[*]}"
  return 0
}

# Main body of script
main() {
  # dns-client check and install
  install_dns_client

  # config renew
  update_dns_config "$DNS_CONFIG_FILE"

  # restart dns client
  restart_dns_client

  # check access
  if ping_test; then
    echo "All hosts are accessible."
  else
    echo "Waiting 3 minutes and repeat."
    sleep 180
    if ! ping_test; then
      echo "Ping cannot pass. Check network configs manually."
    fi
  fi
}

# Automatic script creation
create_autodns_script() {
  mkdir -p /etc/scripts
  
  cat << 'EOF' > "$AUTODNS_SCRIPT"
#!/bin/bash

DNS_SERVERS=($DNS_SERVERS)
DNS_CONFIG_FILE=$DNS_CONFIG_FILE

ping_test() {
  local ping_targets=$PING_CHECK

  for target in "${ping_targets[@]}"; do
    if ! ping -c 4 "$target" > /dev/null 2>&1; then
      echo "Ping cannot access $target"
      return 1
    fi
  done
  echo "Ping successfully checked: ${ping_targets[*]}"
  return 0
}

update_dns_config() {
  echo "# Automatic DNS config" > "$DNS_CONFIG_FILE"
  for server in "${DNS_SERVERS[@]}"; do
    echo "nameserver $server" >> "$DNS_CONFIG_FILE"
  done
  echo "File $DNS_CONFIG_FILE renewed"
}

retry_ping_and_update() {
  local retry_count=0
  local max_retries=5

  while [ $retry_count -lt $max_retries ]; do
    if ping_test; then
      echo "Ping successfully finished"
      exit 0
    else
      echo "Ping cannot pass, waiting 3 mins & retry"
      sleep 300
      ((retry_count++))
    fi
  done

  echo "Ping cannot pass in $max_retries retries. Renewing DNS config."
  update_dns_config
  systemctl restart systemd-resolved
}

retry_ping_and_update
EOF

  chmod +x "$AUTODNS_SCRIPT"
}

# Cron question
setup_cron_check() {
  echo "Wish to add automatic cron schedule of script to be executed at 00:00 and 12:00)? (yes/no)"
  read -r answer

  if [ "$answer" = "yes" || "y" ]; then
    # Making script
    create_autodns_script

    # Cron schedule
    (crontab -l 2>/dev/null; echo "0 0,12 * * * $AUTODNS_SCRIPT") | crontab -
    echo "Automatic cron scheduled execution added."
  fi
}

# Main body of script
main

# Func of cron
setup_cron_check
