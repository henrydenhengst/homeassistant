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



#!/bin/bash
set -e
set -o pipefail

LOG_FILE="$HOME/hardware-check.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "START HARDWARE CHECK $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# -------------------------------
# Basis systeemchecks
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
# Schijf Gezondheid (SMART)
# -------------------------------
apt update && apt install -y smartmontools lm-sensors stress-ng lsblk usbutils jq curl

DISKS=$(lsblk -dno NAME,MODEL,SIZE | grep -vE "loop|boot|rpmb|sr")

PROBLEMS_FOUND=0
PROBLEM_DISKS=()

for disk_info in $DISKS; do
    read -r NAME MODEL SIZE <<< "$disk_info"
    DEV="/dev/$NAME"
    echo -e "\n💾 Schijf: $DEV [$MODEL - $SIZE]"
    echo "----------------------------------------------------"

    STATUS=$(smartctl -H "$DEV" 2>/dev/null | awk -F': ' '/overall-health/ {gsub(/ /,"",$2); print $2}')
    [[ -z "$STATUS" ]] && STATUS="UNKNOWN"

    if [[ "$STATUS" != "PASSED" && "$STATUS" != "OK" && "$STATUS" != "UNKNOWN" ]]; then
        echo -e "❌ KRITIEKE FOUT: $DEV status = $STATUS"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
        PROBLEM_DISKS+=("$DEV - $STATUS")
    fi

    ATTRS=$(smartctl -A "$DEV" 2>/dev/null)
    REALLOC=$(echo "$ATTRS" | awk '/Reallocated_Sector_Ct/ {print $10}')
    PENDING=$(echo "$ATTRS" | awk '/Current_Pending_Sector/ {print $10}')

    if [[ "$REALLOC" -gt 0 || "$PENDING" -gt 0 ]]; then
        echo -e "❌ Fysieke fouten gedetecteerd op $DEV (Realloc:$REALLOC Pending:$PENDING)"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
        PROBLEM_DISKS+=("$DEV - fysieke schade (Realloc:$REALLOC Pending:$PENDING)")
    fi

    if [[ "$NAME" == nvme* ]]; then
        TEMP=$(echo "$ATTRS" | awk '/Temperature/ {print $2 " " $3}')
        WEAR=$(echo "$ATTRS" | awk -F': ' '/Percentage Used/ {print $2}')
        echo "🌡️  Temperatuur: $TEMP"
        echo "📉 Slijtage (Used): ${WEAR:-0}%"
    else
        HOURS=$(echo "$ATTRS" | awk '/Power_On_Hours/ {print $10}')
        echo "🕒 Branduren: ${HOURS:-0} uur"
    fi
done

echo -e "\n===================================================="
if [[ $PROBLEMS_FOUND -eq 0 ]]; then
    echo "✅ Alle schijven lijken gezond."
else
    echo "⚠️  Problemen gedetecteerd op $PROBLEMS_FOUND schijf(en):"
    for disk in "${PROBLEM_DISKS[@]}"; do
        echo " - $disk"
    done
fi
echo "===================================================="

# -------------------------------
# Geheugen (RAM) check
# -------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

MEM_ERRORS=$(dmesg --ctime | grep -iE "memory error|ECC error|Corrected error|Uncorrected error" || true)
if [[ -n "$MEM_ERRORS" ]]; then
    echo -e "${RED}❌ Geheugenfouten gedetecteerd!${NC}"
    echo "$MEM_ERRORS" | tail -n 5
    exit 1
else
    echo -e "${GREEN}✅ Geen geheugenfouten gevonden in systeemlogs.${NC}"
fi

read -p "Wil je een actieve RAM-test uitvoeren met memtester? [y/N]: " do_memtest
if [[ "$do_memtest" =~ ^[Yy]$ ]]; then
    apt install -y memtester
    TEST_MB=$(( TOTAL_RAM_MB / 4 ))
    (( TEST_MB > 8192 )) && TEST_MB=8192
    memtester "${TEST_MB}M" 1
fi

# -------------------------------
# CPU Temperatuur & Stabiliteit
# -------------------------------
if command -v sensors &> /dev/null; then
    TEMP=$(sensors | grep "Package id 0:" | awk '{print $4}' | tr -d '+°C' | cut -d. -f1)
    if [[ -n "$TEMP" && "$TEMP" -gt 80 ]]; then
        echo "⚠️  CPU is te heet ($TEMP°C)"
    else
        echo "✅ CPU temperatuur OK: $TEMP°C"
    fi
fi

if command -v stress-ng &> /dev/null; then
    echo "⚡ Korte CPU stress-test (15s)..."
    stress-ng --cpu $(nproc) -t 15s --quiet || { echo "❌ CPU onstabiel"; exit 1; }
    echo "✅ CPU stabiel onder korte stress-test"
fi

# -------------------------------
# Voeding / Undervoltage check (Raspberry Pi)
# -------------------------------
if command -v vcgencmd &> /dev/null; then
    UNDERVOLT=$(vcgencmd get_throttled | grep -v "0x0" || true)
    if [[ -n "$UNDERVOLT" ]]; then
        echo "❌ Undervoltage gedetecteerd! Controleer voeding"
    else
        echo "✅ Voeding stabiel"
    fi
fi

echo "===================================================="
echo "✅ Hardware check voltooid"


# =====================================================
# Basis tools
# =====================================================
apt update && apt install -y \
  apt-transport-https ca-certificates curl gnupg lsb-release \
  ufw openssh-server usbutils bluetooth bluez fail2ban vim nano \
  ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd \
  unattended-upgrades duff rsync moreutils unzip mtr dnsutils \
  tcpdump tshark lsof ipcalc lshw smartmontools memtester


# =====================================================
# Officiële Docker installatie voor Debian 13
# =====================================================
echo "📦 Installatie van Docker via officiële Docker repository..."

# Verwijder oudere versies (indien aanwezig)
apt remove -y docker docker-engine docker.io containerd runc || true

# Vereiste pakketten
apt update
apt install -y \
    ca-certificates curl gnupg lsb-release software-properties-common

# Voeg Docker GPG key toe
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Voeg Docker repository toe
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update pakketlijst en installeer Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker service activeren
systemctl enable docker
systemctl restart docker

# Controleer Docker versie
docker --version

# =====================================================
# Directories
# =====================================================
echo "📂 Aanmaken van stack- en backup directories..."
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
         "$STACK_DIR/duckdns" \
         "$STACK_DIR/gotify" \
         "$STACK_DIR/appdaemon" \
         "$STACK_DIR/appdaemon/config" \
         "$STACK_DIR/appdaemon/apps"

if [ $? -eq 0 ]; then
    echo "✅ Directories succesvol aangemaakt."
else
    echo "⚠️ Fout bij aanmaken van directories!"
fi

# =====================================================
# Iconen voor Homepage downloaden
# =====================================================
echo "📥 Iconen voor Homepage ophalen..."
declare -A ICONS=(
    ["home-assistant.png"]="https://raw.githubusercontent.com/home-assistant/brands/main/home-assistant/home-assistant.png"
    ["portainer.png"]="https://raw.githubusercontent.com/portainer/portainer/main/app/images/icon.png"
    ["nodered.png"]="https://raw.githubusercontent.com/node-red/node-red.github.io/master/images/red.png"
    ["beszel.png"]="https://raw.githubusercontent.com/henrygd/beszel/main/assets/beszel.png"
    ["uptime-kuma.png"]="https://raw.githubusercontent.com/louislam/uptime-kuma/develop/public/logo.png"
    ["it-tools.png"]="https://raw.githubusercontent.com/corentinth/it-tools/main/assets/it-tools.png"
    ["mosquitto.png"]="https://raw.githubusercontent.com/eclipse/mosquitto/master/src/mosquitto.png"
    ["zigbee2mqtt.png"]="https://raw.githubusercontent.com/Koenkk/zigbee2mqtt.io/master/docs/img/logo.png"
    ["zwavejs2mqtt.png"]="https://raw.githubusercontent.com/zwave-js/zwavejs2mqtt/master/docs/img/logo.png"
    ["esphome.png"]="https://raw.githubusercontent.com/esphome/esphome-docs/main/docs/_static/logo.png"
    ["watchtower.png"]="https://raw.githubusercontent.com/containrrr/watchtower/master/assets/logo.png"
    ["dozzle.png"]="https://raw.githubusercontent.com/amir20/dozzle/master/docs/dozzle-logo.png"
    ["influxdb.png"]="https://raw.githubusercontent.com/influxdata/influxdb/master/assets/images/influxdb-logo.png"
    ["grafana.png"]="https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg"
    ["crowdsec.png"]="https://raw.githubusercontent.com/crowdsecurity/crowdsec/main/docs/images/crowdsec.png"
    ["duckdns.png"]="https://www.duckdns.org/assets/duckdns-icon.png"
    ["p1monitor.png"]="https://raw.githubusercontent.com/nielstron/p1monitor/main/public/logo.png"

["appdaemon.png"]="https://raw.githubusercontent.com/acockburn/appdaemon/master/docs/_static/appdaemon_logo.png"
    ["gotify.png"]="https://gotify.net/static/img/logo-192.png"  # <-- Gotify icoon toegevoegd
)

for ICON in "${!ICONS[@]}"; do
    URL=${ICONS[$ICON]}
    echo "⬇️ Downloaden van $ICON..."
    if curl -sSL "$URL" -o "$STACK_DIR/homepage/config/$ICON"; then
        echo "✅ $ICON gedownload"
    else
        echo "⚠️ Fout bij downloaden van $ICON"
    fi
done

echo "🎉 Alle iconen verwerkt in $STACK_DIR/homepage/config/"



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
    - Node-RED:
        icon: nodered.png
        href: http://$IP:2136
        description: Automatisering Workflows
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


  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports:
      - "2136:1880"       # Externe poort 2136 naar interne Node-RED poort 1880
    volumes:
      - ./nodered_data:/data
    environment:
      - TZ=Europe/Amsterdam
    depends_on:
      - mosquitto          # Voor MQTT integratie met Home Assistant
      - homeassistant

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

  gotify:
    image: gotify/server:2.0
    container_name: gotify
    restart: unless-stopped
    ports:
      - "8137:80"       # Externe poort 8137 → interne Gotify poort 80
    volumes:
      - ./data:/app/data

  appdaemon:
    image: acockburn/appdaemon:latest
    container_name: appdaemon
    restart: unless-stopped
    depends_on:
      - homeassistant  # Zorgt dat HA container eerst start
    environment:
    # Gebruik .env variabelen voor veilige configuratie
      - HA_URL=http://${JUST_IP}:8123    # Home Assistant URL (API poort 8123)
      - TOKEN=${APPDAEMON_TOKEN}         # Home Assistant Long-Lived Access Token
      - DASH_URL=http://0.0.0.0:5050     # HADashboard URL (optioneel)
    volumes:
      - ./appdaemon:/conf                # appdaemon.yaml en configuratie
      - ./apps:/conf/apps                # Python apps/automatiseringen
    ports:
      - "8138:5050"                      # Externe poort 8138 → interne HADashboard 5050

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

 =====================================================
# POST-INSTALLATIE CHECK: Controleer of alles draait
# Beszel Hub wordt NIET meegenomen (handleiding staat apart)
# =====================================================

STACK_DIR="$HOME/home-assistant"
DOCKER_COMPOSE_FILE="$STACK_DIR/docker-compose.yml"
HA_IP=$(hostname -I | awk '{print $1}')

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n===================================================="
echo "✅ Start post-installatie checks..."
echo "===================================================="

# 1️⃣ Docker daemon
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✅ Docker service actief${NC}"
else
    echo -e "${RED}❌ Docker service is niet actief!${NC}"
fi

# 2️⃣ Controleer status van containers (exclusief Beszel)
EXCLUDE_CONTAINERS="beszel beszel-agent"
ALL_CONTAINERS=$(docker compose -f "$DOCKER_COMPOSE_FILE" config --services)
RUNNING_CONTAINERS=$(docker compose -f "$DOCKER_COMPOSE_FILE" ps --services --filter "status=running")

echo -e "\n📦 Controleer containers status..."
for c in $ALL_CONTAINERS; do
    if [[ $EXCLUDE_CONTAINERS =~ $c ]]; then
        continue
    fi

    if grep -q "^$c$" <<< "$RUNNING_CONTAINERS"; then
        echo -e "${GREEN}✅ Container '$c' draait${NC}"
    else
        echo -e "${RED}❌ Container '$c' draait NIET${NC}"
    fi
done

# 3️⃣ Home Assistant bereikbaarheid
if curl -s -m 5 http://$HA_IP:8123 > /dev/null; then
    echo -e "${GREEN}✅ Home Assistant bereikbaar op http://$HA_IP:8123${NC}"
else
    echo -e "${RED}❌ Home Assistant niet bereikbaar${NC}"
fi

# 4️⃣ MariaDB connectie
if docker exec mariadb mysql -uhomeassistant -psecretpassword -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ MariaDB database OK${NC}"
else
    echo -e "${RED}❌ MariaDB connectie mislukt${NC}"
fi

# 5️⃣ Mosquitto broker
if nc -zv $HA_IP 8120 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Mosquitto MQTT broker actief${NC}"
else
    echo -e "${RED}❌ Mosquitto broker niet bereikbaar${NC}"
fi

# 6️⃣ Homepage dashboard
if nc -zv $HA_IP 8133 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Homepage dashboard actief${NC}"
else
    echo -e "${RED}❌ Homepage dashboard niet bereikbaar${NC}"
fi

echo -e "\n===================================================="
echo "✅ Post-installatie check voltooid!"
echo "⚠️ Beszel Hub wordt apart geregeld volgens instructies"
echo "Controleer eventuele foutmeldingen hierboven en start ontbrekende containers handmatig:"
echo "docker compose -f $DOCKER_COMPOSE_FILE up -d [containernaam]"
echo "===================================================="

echo -e "\n===================================================="
echo "📋 Samenvatting Webservices Status"
echo "===================================================="

declare -A SERVICES=(
    ["Home Assistant"]="8123"
    ["Mosquitto"]="8120"
    ["Zigbee2MQTT"]="8121"
    ["Z-Wave JS"]="8129"
    ["ESPHome"]="8122"
    ["Node-RED"]="2136"
    ["Portainer"]="8124"
    ["Watchtower"]="--"
    ["Dozzle"]="8126"
    ["InfluxDB"]="8127"
    ["Grafana"]="8128"
    ["Homepage"]="8133"
    ["Uptime Kuma"]="8132"
    ["IT-Tools"]="8135"
    ["CrowdSec"]="8134"
    ["Gotify"]="8137"
    ["DuckDNS"]="--"
    ["AppDaemon"]="8138"
)

for name in "${!SERVICES[@]}"; do
    port=${SERVICES[$name]}
    if [[ "$port" != "--" ]]; then
        if nc -zv "$HA_IP" "$port" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $name actief op poort $port${NC}"
        else
            echo -e "${RED}❌ $name NIET bereikbaar op poort $port${NC}"
        fi
    else
        # Controleer enkel container draait
        if docker compose -f "$DOCKER_COMPOSE_FILE" ps -q "$name" | grep -q .; then
            echo -e "${GREEN}✅ $name container draait${NC}"
        else
            echo -e "${RED}❌ $name container NIET actief${NC}"
        fi
    fi
done
echo -e "====================================================\n"

if nc -zv $HA_IP 2136 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Node-RED actief op poort 2136${NC}"
else
    echo -e "${RED}❌ Node-RED NIET bereikbaar op poort 2136${NC}"
fi

# =====================================================
# Post-install instructies voor Beszel
# =====================================================
echo -e "\n===================================================="
echo "✅ Installatie voltooid!"
echo "Ga naar de Beszel Hub (poort 8131), kopieer je Public Key,"
echo "plak deze in je .env (indien gewenst) en draai opnieuw:"
echo "docker compose up -d"
echo "===================================================="