#!/bin/bash
set -e
set -o pipefail

########################################
# CONFIG
########################################

STACK_DIR="$HOME/home-assistant"
ENV_FILE="$STACK_DIR/.env"
LOG_FILE="$HOME/full-pro-install.log"

MIN_DISK_GB=15
MIN_RAM_MB=4000

DNS1="9.9.9.9"
DNS2="1.1.1.1"
DNS3="8.8.8.8"

########################################
# LOGGING
########################################

exec > >(tee -a "$LOG_FILE") 2>&1

echo "====================================="
echo "FULL PRO STACK INSTALL"
echo "====================================="

########################################
# ROOT CHECK
########################################

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

########################################
# RESOURCE CHECK
########################################

FREE_DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

if [[ $FREE_DISK_GB -lt $MIN_DISK_GB ]]; then
  echo "Not enough disk"
  exit 1
fi

if [[ $TOTAL_RAM_MB -lt $MIN_RAM_MB ]]; then
  echo "Not enough RAM"
  exit 1
fi

########################################
# BASE PACKAGES
########################################

echo "Installing base packages"

apt-get update
apt-get install -y \
ca-certificates curl gnupg lsb-release \
ufw openssh-server git vim nano htop \
smartmontools jq unzip rsync \
dnsutils net-tools usbutils \
fail2ban unattended-upgrades

########################################
# DOCKER INSTALL (OFFICIAL)
########################################

echo "Installing Docker"

apt-get remove -y docker docker.io containerd runc || true

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg \
| gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian bookworm stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

########################################
# DIRECTORIES
########################################

mkdir -p "$STACK_DIR"
mkdir -p "$STACK_DIR"/{homeassistant,mariadb,mosquitto,zigbee2mqtt,zwavejs2mqtt,esphome,portainer,influxdb,grafana,dozzle,homepage,uptime-kuma,it-tools,crowdsec,duckdns,gotify,appdaemon,beszel_data}

########################################
# USB DEVICE DETECT (ALLEEN DEVICES)
########################################

detect_usb() {
  ls $1 2>/dev/null | head -n1 || true
}

ZIGBEE_USB=$(detect_usb "/dev/serial/by-id/*zigbee*")
ZWAVE_USB=$(detect_usb "/dev/serial/by-id/*zwave*")
RF_USB=$(detect_usb "/dev/serial/by-id/*rfx*")

echo "USB DEVICES:"
echo "Zigbee: ${ZIGBEE_USB:-NONE}"
echo "ZWave : ${ZWAVE_USB:-NONE}"
echo "RF    : ${RF_USB:-NONE}"

########################################
# FIREWALL
########################################

ufw default deny incoming
ufw default allow outgoing
ufw allow 22
ufw allow 8120:8150/tcp
ufw --force enable

########################################
# DOCKER COMPOSE
########################################

cat > "$STACK_DIR/docker-compose.yml" <<EOF
services:

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports:
      - 8123:8123
    volumes:
      - ./homeassistant:/config
    environment:
      - TZ=Europe/Amsterdam
    depends_on:
      - mariadb
      - mosquitto

  mariadb:
    image: mariadb:10.11
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
    restart: unless-stopped
    ports:
      - 8120:1883
    volumes:
      - ./mosquitto:/mosquitto

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    restart: unless-stopped
    ports:
      - 8121:8080
    devices:
      - ${ZIGBEE_USB:-/dev/ttyUSB0}:/dev/ttyUSB0
    volumes:
      - ./zigbee2mqtt:/app/data
    depends_on:
      - mosquitto

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    restart: unless-stopped
    ports:
      - 8129:8091
    devices:
      - ${ZWAVE_USB:-/dev/ttyUSB1}:/dev/ttyUSB0
    volumes:
      - ./zwavejs2mqtt:/usr/src/app/store

  esphome:
    image: ghcr.io/esphome/esphome
    restart: unless-stopped
    ports:
      - 8122:6052
    volumes:
      - ./esphome:/config

  portainer:
    image: portainer/portainer-ce
    restart: unless-stopped
    ports:
      - 8124:9000
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer:/data

  influxdb:
    image: influxdb:2.7
    restart: unless-stopped
    ports:
      - 8127:8086
    volumes:
      - ./influxdb:/var/lib/influxdb2

  grafana:
    image: grafana/grafana-oss
    restart: unless-stopped
    ports:
      - 8128:3000
    volumes:
      - ./grafana:/var/lib/grafana

  dozzle:
    image: amir20/dozzle
    restart: unless-stopped
    ports:
      - 8126:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  homepage:
    image: ghcr.io/gethomepage/homepage
    restart: unless-stopped
    ports:
      - 8133:3000
    volumes:
      - ./homepage:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    restart: unless-stopped
    ports:
      - 8132:3001
    volumes:
      - ./uptime-kuma:/app/data

  it-tools:
    image: corentinth/it-tools
    restart: unless-stopped
    ports:
      - 8135:8080

  crowdsec:
    image: crowdsecurity/crowdsec
    restart: unless-stopped
    ports:
      - 8134:8080
    volumes:
      - ./crowdsec:/etc/crowdsec

  gotify:
    image: gotify/server
    restart: unless-stopped
    ports:
      - 8137:80
    volumes:
      - ./gotify:/app/data

  appdaemon:
    image: acockburn/appdaemon
    restart: unless-stopped
    ports:
      - 8138:5050
    volumes:
      - ./appdaemon:/conf

  beszel:
    image: henrygd/beszel
    restart: unless-stopped
    ports:
      - 8131:8090
    volumes:
      - ./beszel_data:/data

  watchtower:
    image: containrrr/watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400

  duckdns:
    image: linuxserver/duckdns
    restart: unless-stopped
    environment:
      - SUBDOMAINS=myhome
      - TOKEN=changeme
      - TZ=Europe/Amsterdam
EOF

########################################
# START STACK
########################################

cd "$STACK_DIR"
docker compose up -d

echo "====================================="
echo "FULL PRO STACK READY"
echo "====================================="