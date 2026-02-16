#!/bin/bash
# =====================================================
# FULL PRO HOMELAB INSTALLER
# Gebaseerd op .env configuratie
# =====================================================

set -e
set -o pipefail

# =====================================================
# Laad .env
# =====================================================
STACK_DIR="$HOME/home-assistant"
ENV_FILE="$STACK_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env bestand niet gevonden in $STACK_DIR"
    exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

LOG_FILE="$HOME/ha-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "Stack directory: $STACK_DIR"
echo "===================================================="

# =====================================================
# Root check & systeem resources
# =====================================================
if [[ $EUID -ne 0 ]]; then
    echo "❌ Run dit script als root"
    exit 1
fi

FREE_DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

if [[ $FREE_DISK_GB -lt 14 || $TOTAL_RAM_MB -lt 3000 ]]; then
    echo "❌ Onvoldoende systeembronnen: Schijf=${FREE_DISK_GB}GB, RAM=${TOTAL_RAM_MB}MB"
    exit 1
fi

# =====================================================
# Update + basis tools
# =====================================================
apt-get update && apt-get install -y \
  apt-transport-https ca-certificates curl gnupg lsb-release \
  ufw openssh-server fail2ban vim nano git htop jq unzip \
  unattended-upgrades docker-compose-plugin

# =====================================================
# Docker installeren (indien niet aanwezig)
# =====================================================
if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Docker installeren..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    systemctl enable docker
    systemctl restart docker
fi

docker --version

# =====================================================
# Directories aanmaken
# =====================================================
mkdir -p "$STACK_DIR" "$STACK_DIR/backups" \
    "$STACK_DIR/homeassistant" \
    "$STACK_DIR/zigbee2mqtt" \
    "$STACK_DIR/zwavejs2mqtt" \
    "$STACK_DIR/ble2mqtt" \
    "$STACK_DIR/rfxtrx" \
    "$STACK_DIR/mqtt-ir" \
    "$STACK_DIR/p1monitor" \
    "$STACK_DIR/esphome" \
    "$STACK_DIR/nodered_data" \
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
    "$STACK_DIR/duckdns" \
    "$STACK_DIR/gotify" \
    "$STACK_DIR/appdaemon/apps" \
    "$STACK_DIR/appdaemon/config"

# =====================================================
# Home Assistant configuratie
# =====================================================
HA_CONFIG_FILE="$STACK_DIR/homeassistant/configuration.yaml"

if [ ! -f "$HA_CONFIG_FILE" ]; then
cat > "$HA_CONFIG_FILE" <<EOF
homeassistant:
  name: Home
  latitude: 52.0
  longitude: 5.0
  elevation: 10
  unit_system: metric
  time_zone: ${HA_TZ}

recorder:
  db_url: mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@mariadb/${MYSQL_DATABASE}?charset=utf8mb4
EOF
fi

# =====================================================
# Docker Compose FULL PRO
# =====================================================
cat > "$STACK_DIR/docker-compose.yml" <<EOF

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports:
      - "8123:8123"
    volumes:
      - ./homeassistant:/config
    environment:
      - TZ=${HA_TZ}
    depends_on:
      - mariadb
      - mosquitto

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "8120:1883"
    environment:
      - TZ=${HA_TZ}
    volumes:
      - ./mosquitto:/mosquitto

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports:
      - "8121:8080"
    devices:
      - "${ZIGBEE_USB:-}"
    volumes:
      - ./zigbee2mqtt:/app/data
    environment:
      - TZ=${HA_TZ}
    depends_on:
      - mosquitto

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports:
      - "8129:8091"
    devices:
      - "${ZWAVE_USB:-}"
    volumes:
      - ./zwavejs2mqtt:/usr/src/app/store
    environment:
      - TZ=${HA_TZ}

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    restart: unless-stopped
    ports:
      - "8122:6052"
    volumes:
      - ./esphome:/config

  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports:
      - "2136:1880"
    volumes:
      - ./nodered_data:/data
    environment:
      - TZ=${HA_TZ}
      - NODE_RED_TOKEN=${NODE_RED_TOKEN}
    depends_on:
      - mosquitto
      - homeassistant

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    ports:
      - "8124:9000"
      - "8125:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${PORTAINER_VOLUME}:/data

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
    ports:
      - "8126:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    restart: unless-stopped
    ports:
      - "8127:8086"
    volumes:
      - ./influxdb:/var/lib/influxdb2

  grafana:
    image: grafana/grafana-oss
    container_name: grafana
    restart: unless-stopped
    ports:
      - "8128:3000"
    volumes:
      - ./grafana:/var/lib/grafana

  beszel:
    image: henrygd/beszel:latest
    container_name: beszel
    restart: unless-stopped
    ports:
      - "8131:8090"
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
    ports:
      - "8133:3000"
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "8132:3001"
    volumes:
      - ./uptime-kuma:/app/data

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports:
      - "8135:8080"
    volumes:
      - ./it-tools:/data

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    ports:
      - "8134:8080"
    volumes:
      - ./crowdsec:/etc/crowdsec

  gotify:
    image: gotify/server:2.0
    container_name: gotify
    restart: unless-stopped
    ports:
      - "8137:80"
    volumes:
      - ./gotify:/app/data

  appdaemon:
    image: acockburn/appdaemon:latest
    container_name: appdaemon
    restart: unless-stopped
    depends_on:
      - homeassistant
    environment:
      - HA_URL=http://${JUST_IP}:8123
      - TOKEN=${APPDAEMON_TOKEN}
      - DASH_URL=http://0.0.0.0:5050
    volumes:
      - ./appdaemon/config:/conf
      - ./appdaemon/apps:/conf/apps
    ports:
      - "8138:5050"

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${HA_TZ}
      - SUBDOMAINS=${DUCKDNS_SUB}
      - TOKEN=${DUCKDNS_TOKEN}

volumes:
  ${PORTAINER_VOLUME}:
EOF

# =====================================================
# Containers starten
# =====================================================
cd "$STACK_DIR"
docker compose up -d

# =====================================================
# Tokens automatisch genereren als auto
# =====================================================
generate_token() { openssl rand -hex 32; }

update_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

TOKENS_UPDATED=false

if [ "$NODE_RED_TOKEN" = "auto" ]; then
    update_env_var NODE_RED_TOKEN $(generate_token)
    TOKENS_UPDATED=true
fi

if [ "$APPDAEMON_TOKEN" = "auto" ]; then
    update_env_var APPDAEMON_TOKEN $(generate_token)
    TOKENS_UPDATED=true
fi

$TOKENS_UPDATED && docker restart nodered appdaemon

echo "🎉 FULL PRO Home Assistant stack geïnstalleerd en draait!"