#!/bin/bash
# =====================================================
# FULL PRO HOMELAB INSTALLER - Debian 13
# =====================================================
set -e
set -o pipefail

# -------------------------------
# Directories & env
# -------------------------------
STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
ENV_FILE="$STACK_DIR/.env"

mkdir -p "$STACK_DIR" "$BACKUP_DIR"

# -------------------------------
# Minimaal systeemcontrole
# -------------------------------
MIN_DISK_GB=15
MIN_RAM_MB=4000

FREE_DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

if [[ $FREE_DISK_GB -lt $MIN_DISK_GB || $TOTAL_RAM_MB -lt $MIN_RAM_MB ]]; then
    echo "❌ Onvoldoende systeembronnen: Schijf=${FREE_DISK_GB}GB, RAM=${TOTAL_RAM_MB}MB"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "❌ Run als root."
   exit 1
fi

# -------------------------------
# Maak .env aan als het niet bestaat
# -------------------------------
if [ ! -f "$ENV_FILE" ]; then
cat > "$ENV_FILE" <<EOF
# -------------------------------
# NETWERK CONFIG
# -------------------------------
STATIC_IP=192.168.178.2/24
JUST_IP=192.168.178.2
GATEWAY=192.168.178.1
DNS1=9.9.9.9
DNS2=1.1.1.1
DNS3=8.8.8.8

# -------------------------------
# HOME ASSISTANT
# -------------------------------
HA_TZ=Europe/Amsterdam

# -------------------------------
# MariaDB
# -------------------------------
MYSQL_ROOT_PASSWORD=supersecret
MYSQL_USER=hauser
MYSQL_PASSWORD=supersecretpass
MYSQL_DATABASE=homeassistant

# -------------------------------
# MQTT (Mosquitto)
# -------------------------------
MQTT_USER=hauser
MQTT_PASSWORD=supersecretpass

# -------------------------------
# DuckDNS
# -------------------------------
DUCKDNS_SUB=myhome
DUCKDNS_TOKEN=xxxxxxxxxxxxxx

# -------------------------------
# USB Devices (optioneel)
# -------------------------------
ZIGBEE_USB=/dev/null
ZWAVE_USB=/dev/null
BLE_USB=/dev/null
RF_USB=/dev/null
IR_USB=/dev/null
P1_USB=/dev/null
BT_USB=/dev/null

# -------------------------------
# Docker volumes & tokens
# -------------------------------
PORTAINER_VOLUME=portainer_data
APPDAEMON_TOKEN=auto
NODE_RED_TOKEN=auto
EOF
fi

# Laad .env
export $(grep -v '^#' "$ENV_FILE" | xargs)

# -------------------------------
# Basis tools installeren
# -------------------------------
apt-get update && apt-get install -y \
    apt-transport-https ca-certificates curl gnupg lsb-release \
    ufw openssh-server vim nano htop git jq unzip net-tools \
    docker.io docker-compose memtester socat wget lsof

# -------------------------------
# Docker service activeren
# -------------------------------
systemctl enable docker
systemctl restart docker

# -------------------------------
# Directories voor containers
# -------------------------------
for dir in homeassistant zigbee2mqtt zwavejs2mqtt ble2mqtt rfxtrx mqtt-ir p1monitor \
           esphome nodered_data portainer_data watchtower dozzle influxdb grafana \
           beszel_data homepage uptime-kuma it-tools crowdsec duckdns gotify appdaemon apps; do
    mkdir -p "$STACK_DIR/$dir"
done

# -------------------------------
# Tokens genereren indien nodig
# -------------------------------
generate_token() { openssl rand -hex 32; }
update_env_var() {
    key=$1; value=$2
    if grep -q "^$key=" "$ENV_FILE"; then
        sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
    else
        echo "$key=$value" >> "$ENV_FILE"
    fi
}

TOKENS_UPDATED=false

for token_var in NODE_RED_TOKEN APPDAEMON_TOKEN; do
    val=$(grep "^$token_var=" "$ENV_FILE" | cut -d '=' -f2)
    if [ -z "$val" ] || [ "$val" = "auto" ]; then
        new=$(generate_token)
        update_env_var "$token_var" "$new"
        TOKENS_UPDATED=true
    fi
done

# -------------------------------
# Docker Compose genereren
# -------------------------------
cat > "$STACK_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports: ["8123:8123"]
    volumes:
      - ./homeassistant:/config
    environment:
      - TZ=\${HA_TZ}
    depends_on:
      - mariadb
      - mosquitto

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports: ["8120:1883"]
    environment:
      - TZ=\${HA_TZ}
    volumes:
      - ./mosquitto:/mosquitto

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports: ["8121:8080"]
    volumes:
      - ./zigbee2mqtt:/app/data
    devices:
      - \${ZIGBEE_USB}:/dev/ttyUSB0
    environment:
      - TZ=\${HA_TZ}
    depends_on:
      - mosquitto

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports: ["8129:8091"]
    volumes:
      - ./zwavejs2mqtt:/usr/src/app/store
    devices:
      - \${ZWAVE_USB}:/dev/ttyUSB0
    environment:
      - TZ=\${HA_TZ}

  ble2mqtt:
    image: ghcr.io/eblot/ble2mqtt:latest
    container_name: ble2mqtt
    restart: unless-stopped
    environment:
      - TZ=\${HA_TZ}
    devices:
      - \${BLE_USB}:/dev/hci0
    volumes:
      - ./ble2mqtt:/config

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    restart: unless-stopped
    ports: ["8122:6052"]
    volumes:
      - ./esphome:/config

  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports: ["2136:1880"]
    environment:
      - TZ=\${HA_TZ}
      - NODE_RED_TOKEN=\${NODE_RED_TOKEN}
    volumes:
      - ./nodered_data:/data
    depends_on:
      - mosquitto
      - homeassistant

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    ports: ["8124:9000","8125:9443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - \${PORTAINER_VOLUME}:/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400

  dozzle:
    image: amir20/dozzle
    container_name: dozzle
    restart: unless-stopped
    ports: ["8126:8080"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    restart: unless-stopped
    ports: ["8127:8086"]
    volumes:
      - ./influxdb:/var/lib/influxdb2

  grafana:
    image: grafana/grafana-oss
    container_name: grafana
    restart: unless-stopped
    ports: ["8128:3000"]
    volumes:
      - ./grafana:/var/lib/grafana

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
    volumes:
      - ./uptime-kuma:/app/data

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports: ["8135:8080"]
    volumes:
      - ./it-tools:/data

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    ports: ["8134:8080"]
    volumes:
      - ./crowdsec:/etc/crowdsec

  gotify:
    image: gotify/server:2.0
    container_name: gotify
    restart: unless-stopped
    ports: ["8137:80"]
    volumes:
      - ./gotify:/app/data

  appdaemon:
    image: acockburn/appdaemon:latest
    container_name: appdaemon
    restart: unless-stopped
    ports: ["8138:5050"]
    environment:
      - HA_URL=http://${JUST_IP}:8123
      - TOKEN=\${APPDAEMON_TOKEN}
      - DASH_URL=http://0.0.0.0:5050
    volumes:
      - ./appdaemon:/conf
      - ./apps:/conf/apps
    depends_on:
      - homeassistant

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=\${HA_TZ}
      - SUBDOMAINS=\${DUCKDNS_SUB}
      - TOKEN=\${DUCKDNS_TOKEN}

volumes:
  portainer_data:
EOF

# -------------------------------
# Firewall + SSH hardening
# -------------------------------
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 8120:8140/tcp
ufw --force enable

sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
systemctl restart ssh

echo "🎉 Installatie klaar! Start containers:"
docker compose -f "$STACK_DIR/docker-compose.yml" up -d