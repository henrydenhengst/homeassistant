#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK INSTALLER
# Debian 13 Minimal - Secure Plug & Play Setup
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

IT_TOOLS_DIR="$STACK_DIR/it-tools"

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename $file).bak.$(date +%Y%m%d_%H%M%S)"
        echo "📦 Backup gemaakt: $file"
    fi
}

# =====================================================
# Pre-checks
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
# Debian versie check
# =====================================================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" ]]; then
        echo "❌ Alleen Debian-based systemen ondersteund."
        exit 1
    fi
    if [[ "$VERSION_ID" != "13" ]]; then
        echo "⚠️ Getest op Debian 13 (Bookworm)."
        read -p "Wil je doorgaan? (y/N): " proceed
        [[ ! "$proceed" =~ ^[Yy]$ ]] && exit 1
    fi
else
    echo "❌ Kan /etc/os-release niet vinden."
    exit 1
fi

# =====================================================
# Install basis tools
# =====================================================
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release \
ufw openssh-server usbutils bluetooth bluez fail2ban vim nano ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd unattended-upgrades \
duff rsync moreutils unzip mtr dnsutils tcpdump tshark lsof ipcalc lshw

# =====================================================
# Netwerk Hardening (UFW)
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp          # SSH
ufw allow 8120:8140/tcp   # Home Assistant + services range
ufw --force enable

# =====================================================
# Docker installatie
# =====================================================
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$SUDO_USER"

# =====================================================
# Directories
# =====================================================
mkdir -p "$STACK_DIR" "$BACKUP_DIR" "$IT_TOOLS_DIR"
mkdir -p "$STACK_DIR/homepage/config"

# =====================================================
# USB + Bluetooth autodetect
# =====================================================
ZIGBEE_DEVS=()
ZWAVE_DEVS=()
BLE_DEVS=()
RF_DEVS=()
IR_DEVS=()
P1_DEVS=()
BT_DEVS=()

# Serial devices
if [ -d /dev/serial/by-id ]; then
    for DEV in /dev/serial/by-id/*; do
        [[ "$DEV" =~ zigbee|Zigbee ]] && ZIGBEE_DEVS+=("$DEV")
        [[ "$DEV" =~ zwave|Z-Wave ]] && ZWAVE_DEVS+=("$DEV")
        [[ "$DEV" =~ BLE|ble ]] && BLE_DEVS+=("$DEV")
        [[ "$DEV" =~ RF|433|868 ]] && RF_DEVS+=("$DEV")
        [[ "$DEV" =~ IR|ir|broadlink ]] && IR_DEVS+=("$DEV")
        [[ "$DEV" =~ P1|p1 ]] && P1_DEVS+=("$DEV")
    done
fi

# Bluetooth devices
if command -v bluetoothctl >/dev/null 2>&1; then
    while read -r line; do
        [[ "$line" =~ ^Controller\ ([^[:space:]]+) ]] && BT_DEVS+=("${BASH_REMATCH[1]}")
    done < <(bluetoothctl list)
fi

export ZIGBEE_USB="${ZIGBEE_DEVS[0]:-/dev/null}"
export ZWAVE_USB="${ZWAVE_DEVS[0]:-/dev/null}"

# =====================================================
# Homepage basis YAML
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
    - Grafana:
        icon: grafana.png
        href: http://$IP:8128
    - InfluxDB:
        icon: influxdb.png
        href: http://$IP:8127
    - Dozzle:
        icon: dozzle.png
        href: http://$IP:8126

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
# Docker Compose genereren
# =====================================================
cat > "$STACK_DIR/docker-compose.yml" <<EOF
version: "3.9"
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports: ["8123:8123"]
    volumes: ["./homeassistant:/config"]

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: homeassistant
      MYSQL_USER: hauser
      MYSQL_PASSWORD: hapass
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
      - \${ZIGBEE_USB}:/dev/ttyUSB0
    environment: ["TZ=Europe/Amsterdam"]
    depends_on: [mosquitto]

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports: ["8129:8091"]
    volumes: ["./zwavejs2mqtt:/usr/src/app/store"]
    devices:
      - \${ZWAVE_USB}:/dev/ttyUSB0
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
    image: 'henrygd/beszel:latest'
    container_name: beszel
    restart: unless-stopped
    ports:
      - '8131:8090'
    volumes:
      - ./beszel_data:/data

  beszel-agent:
    image: 'henrygd/beszel-agent:latest'
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    ports: ["8132:3001"]
    volumes: ["./uptime-kuma:/app/data"]

  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports:
      - "8133:3000"
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports: ["8135:8080"]
    volumes: ["./it-tools:/data"]

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Amsterdam
volumes:
  portainer_data:
EOF

# =====================================================
# Start containers
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

echo -e "\n✅ Docker containers gestart."

# =====================================================
# Beszel key instructie
# =====================================================
echo -e "\n⚠️ LET OP:"
echo "Ga naar de Beszel Hub (poort 8131), kopieer je Public Key, en plak deze in de beszel-agent configuratie indien nodig."
echo "Draai daarna opnieuw: docker compose up -d"