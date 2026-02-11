check_system() {
  MIN_DISK=14
  MIN_RAM=3000

  DISK=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  RAM=$(free -m | awk '/Mem:/ {print $2}')

  if [[ $DISK -lt $MIN_DISK || $RAM -lt $MIN_RAM ]]; then
    echo "Onvoldoende resources."
    exit 1
  fi
}

install_base_packages() {
  apt update && apt upgrade -y
  apt install -y \
    curl git vim nano htop tmux \
    ufw fail2ban \
    unzip jq lsof dnsutils \
    tcpdump mtr rsync \
    auditd unattended-upgrades
}

summary() {
  IP=$(hostname -I | awk '{print $1}')
  echo "--------------------------------------"
  echo "Home Assistant: http://$IP:8123"
  echo "IT Tools:       http://$IP:8135"
  echo "WireGuard:      51820/udp"
  echo "--------------------------------------"
}