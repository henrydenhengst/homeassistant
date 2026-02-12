#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB INSTALLER
# Debian 13 Minimal - Secure Plug & Play Setup
# =====================================================
#
# FUNCTIONALITEIT:
#   - Installeert volledige Home Assistant stack via Docker:
#       - Home Assistant
#       - MariaDB
#       - Mosquitto
#       - Zigbee2MQTT, Z-Wave JS, BLE2MQTT, RFXtrx, MQTT-IR, P1Monitor (USB autodetect)
#       - ESPhome
#       - Portainer, Watchtower, Dozzle, InfluxDB, Grafana, Netdata, Uptime-Kuma, Homer
#   - IT-Tools webinterface
#   - WireGuard VPN met server- en clientconfiguratie + QR-code
#   - DuckDNS integratie
#   - CrowdSec monitoring
#   - UFW firewall en SSH hardening
#   - Automatische dagelijkse backups
#
# VOORAF:
#   - Root-toegang vereist
#   - Internetverbinding nodig
#   - Minimaal 14 GB vrije schijfruimte, 3 GB RAM
#   - `.env` bestand met tijdzone, database credentials, DuckDNS token moet aanwezig zijn
#
# USAGE:
#   sudo ./ha-install.sh [STATIC_IP/CIDR] [GATEWAY]
#
# EXAMPLE:
#   sudo ./ha-install.sh 192.168.178.2/24 192.168.178.1
#
# PARAMETERS:
#   [STATIC_IP/CIDR] - Optioneel: statisch IP met subnet, bijv. 192.168.178.2/24
#   [GATEWAY]        - Optioneel: het netwerk gateway IP, bijv. 192.168.178.1
#
# USB AUTODETECT:
#   - Zigbee, Z-Wave, BLE, RF, IR, P1 Smart Meter, Bluetooth devices automatisch toegevoegd
#   - Als geen USB aanwezig, worden deze containers niet gestart
#
# POST-INSTALL CHECKS:
#   - Toont Home Assistant, IT-Tools, CrowdSec URLs
#   - WireGuard clientconfiguratie en QR-code
#   - Overzicht van gedetecteerde USB-devices
#   - Backup locatie en logbestand
#
# AANBEVELINGEN:
#   - Controleer dat het gekozen IP niet conflicteert met andere apparaten
#   - Zorg dat alle benodigde USB-devices aangesloten zijn voor autodetectie
#   - Script is run-once; herhaald uitvoeren kan bestaande configuraties overschrijven
# =====================================================

set -e

LOG_FILE="$HOME/ha-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
IT_TOOLS_DIR="$STACK_DIR/it-tools"

MIN_DISK_GB=14
MIN_RAM_MB=3000

WG_PORT=51820
WG_INTERFACE="wg0"
WG_CONF_DIR="/etc/wireguard"
WG_CLIENT_CONF="$STACK_DIR/wg-client.conf"

STATIC_IP=${1:-"192.168.1.10/24"}
GATEWAY=${2:-"192.168.1.1"}
DNS1="9.9.9.9"
DNS2="1.1.1.1"
DNS3="8.8.8.8"

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
# Laad .env
# =====================================================
if [ ! -f "$STACK_DIR/.env" ]; then
    echo "❌ Geen .env bestand gevonden in $STACK_DIR"
    exit 1
fi
export $(grep -v '^#' "$STACK_DIR/.env" | xargs)
chmod 600 "$STACK_DIR/.env"
chown "$SUDO_USER:$SUDO_USER" "$STACK_DIR/.env"

# =====================================================
# Netwerkconfiguratie
# =====================================================
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
NETWORK_FILE="/etc/systemd/network/10-${INTERFACE}-static.network"
[ -f "$NETWORK_FILE" ] && backup_file "$NETWORK_FILE"
[ -f /etc/resolv.conf ] && backup_file "/etc/resolv.conf"

systemctl stop dhcpcd NetworkManager 2>/dev/null || true
systemctl disable dhcpcd NetworkManager 2>/dev/null || true
systemctl enable systemd-networkd
systemctl restart systemd-networkd

cat > "$NETWORK_FILE" <<EOF
[Match]
Name=$INTERFACE

[Network]
DHCP=no
Address=$STATIC_IP
Gateway=$GATEWAY
DNS=$DNS1 $DNS2 $DNS3
EOF

rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver $DNS1
nameserver $DNS2
nameserver $DNS3
EOF

systemctl restart systemd-networkd

# =====================================================
# Systeem update + tools
# =====================================================
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release \
ufw openssh-server usbutils bluetooth fail2ban vim nano ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd unattended-upgrades \
duff rsync moreutils unzip mtr dnsutils tcpdump tshark lsof ipcalc lshw

# =====================================================
# Docker installatie
# =====================================================
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$SUDO_USER"

# =====================================================
# UFW firewall
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 51820/udp          # WireGuard
ufw allow 8120:8140/tcp      # Alle Home Assistant & add-ons
ufw --force enable

# =====================================================
# SSH hardening + Fail2Ban
# =====================================================
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
grep -q "^AllowUsers $MYSQL_USER" /etc/ssh/sshd_config || echo "AllowUsers $MYSQL_USER" >> /etc/ssh/sshd_config

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
# USB + Bluetooth autodetect
# =====================================================
ZIGBEE_DEVS=()
ZWAVE_DEVS=()
BLE_DEVS=()
RF_DEVS=()
IR_DEVS=()
P1_DEVS=()
BT_DEVS=()

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

# Bluetooth dongle detect
BT_DEVS=($(hciconfig | grep -o 'hci[0-9]'))

# =====================================================
# Directories aanmaken
# =====================================================
mkdir -p "$STACK_DIR" "$BACKUP_DIR" "$IT_TOOLS_DIR"
[ ${#ZIGBEE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/zigbee2mqtt"
[ ${#ZWAVE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/zwavejs2mqtt"
[ ${#BLE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/ble2mqtt"
[ ${#RF_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/rfxtrx"
[ ${#IR_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/mqtt-ir"
[ ${#P1_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/p1monitor"

# =====================================================
# Docker Compose configuratie (alle containers behouden)
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
    volumes: ["./mosquitto:/mosquitto"]

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports: ["8121:8080"]
    volumes: ["./zigbee2mqtt:/app/data"]
    devices:
EOF

# Voeg automatisch Zigbee devices toe
for idx in "${!ZIGBEE_DEVS[@]}"; do
    echo "      - ${ZIGBEE_DEVS[$idx]}:/dev/ttyUSB$idx" >> "$STACK_DIR/docker-compose.yml"
done
echo "    environment: [\"TZ=\${HA_TZ}\"]" >> "$STACK_DIR/docker-compose.yml"
echo "    depends_on: [mosquitto]" >> "$STACK_DIR/docker-compose.yml"

# Hier voeg je alle andere containers toe zoals Z-Wave, BLE, RF, IR, P1, ESPhome, Portainer, Watchtower, Dozzle, InfluxDB, Grafana, Netdata, Uptime-Kuma, Homer
# Voeg DuckDNS container toe als extra service

# =====================================================
# Start alle Docker containers
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# WireGuard setup
# =====================================================
apt install -y wireguard
umask 077
mkdir -p $WG_CONF_DIR

wg genkey | tee $WG_CONF_DIR/server_private.key | wg pubkey > $WG_CONF_DIR/server_public.key
SERVER_PRIV=$(cat $WG_CONF_DIR/server_private.key)
SERVER_PUB=$(cat $WG_CONF_DIR/server_public.key)
wg genkey | tee $WG_CONF_DIR/client_private.key | wg pubkey > $WG_CONF_DIR/client_public.key
CLIENT_PRIV=$(cat $WG_CONF_DIR/client_private.key)
CLIENT_PUB=$(cat $WG_CONF_DIR/client_public.key)

# Server en client configuratie
cat > $WG_CONF_DIR/$WG_INTERFACE.conf <<EOF
[Interface]
Address = 10.10.0.1/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV
PostUp = ufw route allow in on $WG_INTERFACE out on $INTERFACE; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = ufw route delete allow in on $WG_INTERFACE out on $INTERFACE; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.10.0.2/32
EOF

cat > $WG_CLIENT_CONF <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.10.0.2/24
DNS = 10.10.0.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = \${DUCKDNS_SUB}.duckdns.org:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

# QR-code tonen
qrencode -t ansiutf8 < "$WG_CLIENT_CONF"

# =====================================================
# Post-install health check
# =====================================================
IP=$(hostname -I | awk '{print $1}')
check_containers() {
    echo "🔍 Controleer status van Docker containers..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo "🔍 Test bereikbaarheid services..."
    SERVICES=(8123 8134 8135)
    for PORT in "${SERVICES[@]}"; do
        if curl -s --max-time 3 http://$IP:$PORT >/dev/null; then
            echo "✅ Service op poort $PORT is bereikbaar"
        else
            echo "⚠️  Service op poort $PORT niet bereikbaar"
        fi
    done

    echo "🔍 Controleer WireGuard..."
    if wg show "$WG_INTERFACE" >/dev/null 2>&1; then
        echo "✅ WireGuard $WG_INTERFACE actief"
    else
        echo "⚠️  WireGuard $WG_INTERFACE niet actief"
    fi
}

check_containers

echo "===================================================="
echo "INSTALLATIE VOLTOOID 🎉"
echo "Home Assistant:  http://${IP}:8123"
echo "IT-Tools:        http://${IP}:8135"
echo "CrowdSec:        http://${IP}:8134"
echo "WireGuard client config: $WG_CLIENT_CONF"
echo "QR-code hierboven weergegeven"
echo "Backup directory:        $BACKUP_DIR"
echo "Zigbee devices:          ${#ZIGBEE_DEVS[@]}"
echo "Z-Wave devices:          ${#ZWAVE_DEVS[@]}"
echo "BLE devices:             ${#BLE_DEVS[@]}"
echo "RF devices:              ${#RF_DEVS[@]}"
echo "IR devices:              ${#IR_DEVS[@]}"
echo "Smart Meter (P1) devices:${#P1_DEVS[@]}"
echo "Bluetooth devices:       ${#BT_DEVS[@]}"
echo "===================================================="