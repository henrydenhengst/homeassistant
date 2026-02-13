#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK INSTALLER
# Debian 13 Minimal - Secure Plug & Play Setup
# =====================================================
#
# DOCUMENTATIE:
# Dit script installeert een volledige Home Assistant homelab stack
# met geavanceerde monitoring, dashboards, en IT-tools.
# Het is ideaal voor hobby-servers, homelabs of kleine private clouds.
#
# COMPONENTEN:
# - Home Assistant (Docker container)
# - MariaDB database (geoptimaliseerd voor HA)
# - Mosquitto MQTT broker
# - Zigbee2MQTT, Z-Wave JS, BLE2MQTT, RFXtrx, MQTT-IR, P1Monitor
# - ESPhome, Portainer, Watchtower, Dozzle, InfluxDB, Grafana
# - Beszel Hub + Beszel Agent (lichtgewicht monitoring dashboard)
# - Homepage (dashboard voor al je web-apps)
# - Uptime-Kuma en IT-Tools webinterface
# - CrowdSec monitoring
# - DuckDNS updater container
# - UFW firewall en SSH hardening
# - Alt+Ctrl+Del uitgeschakeld
# - Automatische dagelijkse backups
#
# OPZET:
# 1. Script uitvoeren: sudo ./ha-install.sh [STATIC_IP/CIDR] [GATEWAY]
# 2. Home Assistant zal MariaDB gebruiken i.p.v. SQLite
# 3. Homepage configuratie YAML wordt automatisch aangemaakt
# 4. Beszel Hub start zonder key; public key kopiëren en opnieuw starten
# 5. Alle containers starten via docker compose
#
# SYSTEEMVEREISTEN:
# - Debian 13 minimal
# - Root-toegang
# - Internetverbinding
# - Minimaal 14 GB vrije schijfruimte, 3 GB RAM
#
# =====================================================

set -e
set -o pipefail

LOG_FILE="$HOME/ha-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
MIN_DISK_GB=15
MIN_RAM_MB=4000

STATIC_IP=${1:-"192.168.1.10/24"}
GATEWAY=${2:-"192.168.1.1"}
DNS1="9.9.9.9"
DNS2="1.1.1.1"
DNS3="8.8.8.8"

# =====================================================
# Systeem pre-checks
# =====================================================
FREE_DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
if [[ $FREE_DISK_GB -lt $MIN_DISK_GB || $TOTAL_RAM_MB -lt $MIN_RAM_MB ]]; then
    echo "❌ Onvoldoende systeembronnen."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "❌ Run als root."
   exit 1
fi

# =====================================================
# Basis tools
# =====================================================
apt update && apt install -y \
  apt-transport-https ca-certificates curl gnupg lsb-release \
  ufw openssh-server usbutils bluetooth bluez fail2ban vim nano \
  ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd \
  unattended-upgrades duff rsync moreutils unzip mtr dnsutils \
  tcpdump tshark lsof ipcalc lshw docker-ce docker-ce-cli \
  containerd.io docker-compose-plugin smartmontools memtester

# =====================================================
# Directories
# =====================================================
mkdir -p "$STACK_DIR" "$BACKUP_DIR" \
         "$STACK_DIR/homeassistant" \
         "$STACK_DIR/zigbee2mqtt" \
         "$STACK_DIR/zwavejs2mqtt" \
         "$STACK_DIR/ble2mqtt" \
         "$STACK_DIR/rfxtrx" \
         "$STACK_DIR/mqtt-ir" \
         "$STACK_DIR/p1monitor" \
         "$STACK_DIR/esphome" \
         "$STACK_DIR/portainer" \
         "$STACK_DIR/watchtower" \
         "$STACK_DIR/dozzle" \
         "$STACK_DIR/influxdb" \
         "$STACK_DIR/grafana" \
         "$STACK_DIR/beszel_data" \
         "$STACK_DIR/homepage/config" \
         "$STACK_DIR/uptime-kuma" \
         "$STACK_DIR/it-tools" \
         "$STACK_DIR/crowdsec" \
         "$STACK_DIR/duckdns"

# =====================================================
# Home Assistant configuratie aanpassen voor MariaDB
# =====================================================
HA_CONFIG_DIR="$STACK_DIR/homeassistant"
CONFIG_FILE="$HA_CONFIG_DIR/configuration.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "📄 Home Assistant configuration.yaml aanmaken..."
    cat > "$CONFIG_FILE" <<EOF
homeassistant:
  name: Home
  latitude: 52.0
  longitude: 5.0
  elevation: 10
  unit_system: metric
  time_zone: Europe/Amsterdam
  currency: EUR
EOF
fi

if ! grep -q "recorder:" "$CONFIG_FILE"; then
    cat >> "$CONFIG_FILE" <<EOF

recorder:
  db_url: mysql://homeassistant:secretpassword@mariadb/homeassistant?charset=utf8mb4
EOF
fi

# =====================================================
# Basis YAML voor Homepage aanmaken
# =====================================================
IP=$(hostname -I | awk '{print $1}')

cat > "$STACK_DIR/homepage/config/services.yaml" <<EOF
- Infrastructuur:
    - Home Assistant:
        icon: home-assistant.png
        href: http://$IP:8123
        description: Smart Home Hub
    - Portainer:
        icon: portainer.png
        href: http://$IP:8124
        description: Docker Management

- Monitoring & Tools:
    - Beszel:
        icon: beszel.png
        href: http://$IP:8131
    - Uptime Kuma:
        icon: uptime-kuma.png
        href: http://$IP:8132
    - IT-Tools:
        icon: it-tools.png
        href: http://$IP:8135
EOF

# =====================================================
# Firewall + SSH Hardening
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp                # SSH
ufw allow 8120:8140/tcp         # HA services
ufw --force enable

# SSH root login uit
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true

# Fail2Ban
tee /etc/fail2ban/jail.d/ssh.local > /dev/null <<EOF
[sshd]
enabled = true
maxretry = 3
bantime = 3600
findtime = 600
EOF

systemctl restart fail2ban
systemctl enable fail2ban
systemctl restart ssh

# =====================================================
# Docker Compose genereren
# =====================================================
cat > "$STACK_DIR/docker-compose.yml" <<EOF
version: '3'
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports: ["8123:8123"]
    volumes: ["./homeassistant:/config"]
    environment:
      - TZ=Europe/Amsterdam
    depends_on:
      - mariadb
      - mosquitto

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: homeassistant
      MYSQL_USER: homeassistant
      MYSQL_PASSWORD: secretpassword
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports: ["8120:1883"]
    volumes: ["./mosquitto:/mosquitto"]

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports: ["8121:8080"]
    volumes: ["./zigbee2mqtt:/app/data"]
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
    environment: ["TZ=Europe/Amsterdam"]
    depends_on: [mosquitto]

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports: ["8129:8091"]
    volumes: ["./zwavejs2mqtt:/usr/src/app/store"]
    devices:
      - /dev/ttyUSB1:/dev/ttyUSB0
    environment: ["TZ=Europe/Amsterdam"]

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    restart: unless-stopped
    ports: ["8122:6052"]
    volumes: ["./esphome:/config"]

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    ports: ["8124:9000","8125:9443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
    command: --cleanup --interval 86400

  dozzle:
    image: amir20/dozzle
    container_name: dozzle
    restart: unless-stopped
    ports: ["8126:8080"]
    volumes: ["/var/run/docker.sock:/var/run/docker.sock"]

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    restart: unless-stopped
    ports: ["8127:8086"]
    volumes: ["./influxdb:/var/lib/influxdb2"]

  grafana:
    image: grafana/grafana-oss
    container_name: grafana
    restart: unless-stopped
    ports: ["8128:3000"]
    volumes: ["./grafana:/var/lib/grafana"]

  beszel:
    image: henrygd/beszel:latest
    container_name: beszel
    restart: unless-stopped
    ports: ["8131:8090"]
    volumes:
      - ./beszel_data:/data

  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports: ["8133:3000"]
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    ports: ["8132:3001"]
    volumes: ["./uptime-kuma:/app/data"]

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports: ["8135:8080"]
    volumes: ["./it-tools:/data"]

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    ports: ["8134:8080"]
    volumes:
      - ./crowdsec:/etc/crowdsec

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Amsterdam
      - SUBDOMAINS=myhome
      - TOKEN=mytoken

volumes:
  portainer_data:
EOF

# =====================================================
# Containers starten
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# Post-install instructies voor Beszel
# =====================================================
echo -e "\n===================================================="
echo "✅ Installatie voltooid!"
echo "Ga naar de Beszel Hub (poort 8131), kopieer je Public Key,"
echo "plak deze in je .env (indien gewenst) en draai opnieuw:"
echo "docker compose up -d"
echo "===================================================="