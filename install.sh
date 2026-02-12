#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK + WireGuard + DuckDNS + QR + IT-TOOLS
# Debian 13 Minimal - Secure Plug & Play Setup
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
# Laad .env
# =====================================================
if [ ! -f "$STACK_DIR/.env" ]; then
    echo "❌ Geen .env bestand"
    exit 1
fi
export $(grep -v '^#' "$STACK_DIR/.env" | xargs)
chmod 600 "$STACK_DIR/.env"
chown "$SUDO_USER:$SUDO_USER" "$STACK_DIR/.env"

# =====================================================
# Netwerk
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
# System update + tools
# =====================================================
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release \
ufw openssh-server usbutils fail2ban vim nano ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd unattended-upgrades \
duff rsync moreutils unzip mtr dnsutils tcpdump tshark lsof ipcalc lshw

# =====================================================
# Docker
# =====================================================
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$SUDO_USER"

# =====================================================
# UFW + SSH
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 51820/udp
for port in {8120..8140}; do ufw allow ${port}/tcp; done
ufw allow 8135/tcp   # IT-Tools
ufw --force enable

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
# USB autodetect
# =====================================================
ZIGBEE_DEVS=()
ZWAVE_DEVS=()
BLE_DEVS=()
RF_DEVS=()
IR_DEVS=()
P1_DEVS=()

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

# =====================================================
# Directories
# =====================================================
mkdir -p "$STACK_DIR" "$BACKUP_DIR" "$IT_TOOLS_DIR"
[ ${#ZIGBEE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/zigbee2mqtt"
[ ${#ZWAVE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/zwavejs2mqtt"
[ ${#BLE_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/ble2mqtt"
[ ${#RF_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/rfxtrx"
[ ${#IR_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/mqtt-ir"
[ ${#P1_DEVS[@]} -gt 0 ] && mkdir -p "$STACK_DIR/p1monitor"

# =====================================================
# Docker Compose setup
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
      - TZ=${HA_TZ}
    depends_on: [mariadb, mosquitto]

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE=${MYSQL_DATABASE}
      MYSQL_USER=${MYSQL_USER}
      MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes: ["./mariadb:/var/lib/mysql"]

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports: ["8120:1883"]
    volumes: ["./mosquitto:/mosquitto"]
EOF

# =====================================================
# Voeg containers toe afhankelijk van autodetect
# =====================================================
# Zigbee
if [ ${#ZIGBEE_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports: ["8121:8080"]
    volumes: ["./zigbee2mqtt:/app/data"]
    devices:
EOF
    for idx in "${!ZIGBEE_DEVS[@]}"; do
        echo "      - ${ZIGBEE_DEVS[$idx]}:/dev/ttyUSB$idx" >> "$STACK_DIR/docker-compose.yml"
    done
    echo "    environment: [\"TZ=${HA_TZ}\"]" >> "$STACK_DIR/docker-compose.yml"
fi

# Z-Wave
if [ ${#ZWAVE_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports: ["8129:8091"]
    volumes: ["./zwavejs2mqtt:/usr/src/app/store"]
    devices:
EOF
    for idx in "${!ZWAVE_DEVS[@]}"; do
        echo "      - ${ZWAVE_DEVS[$idx]}:/dev/ttyUSB$idx" >> "$STACK_DIR/docker-compose.yml"
    done
    echo "    environment: [\"TZ=${HA_TZ}\"]" >> "$STACK_DIR/docker-compose.yml"
fi

# BLE
if [ ${#BLE_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  ble2mqtt:
    image: koenkk/ble2mqtt
    container_name: ble2mqtt
    restart: unless-stopped
    ports: ["8131:8080"]
    volumes: ["./ble2mqtt:/app/data"]
EOF
fi

# RF
if [ ${#RF_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  rfxtrx:
    image: docker-rfxtrx
    container_name: rfxtrx
    restart: unless-stopped
    ports: ["8132:8080"]
    volumes: ["./rfxtrx:/data"]
EOF
fi

# IR
if [ ${#IR_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  mqtt-ir:
    image: mqtt-ir
    container_name: mqtt-ir
    restart: unless-stopped
    ports: ["8133:8080"]
    volumes: ["./mqtt-ir:/data"]
EOF
fi

# P1
if [ ${#P1_DEVS[@]} -gt 0 ]; then
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  p1monitor:
    image: p1monitor
    container_name: p1monitor
    restart: unless-stopped
    ports: ["8134:8080"]
    volumes: ["./p1monitor:/data"]
EOF
fi

# IT-Tools
cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports: ["8135:80"]
    volumes:
      - ./it-tools:/data
EOF

# =====================================================
# Start containers
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# WireGuard
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
Endpoint = ${DUCKDNS_SUB}.duckdns.org:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

# =====================================================
# CrowdSec + Dashboard
# =====================================================
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
apt install -y crowdsec crowdsec-firewall-bouncer crowdsec-ui
systemctl enable crowdsec crowdsec-ui
systemctl start crowdsec crowdsec-ui

# =====================================================
# Cronjob auto-backup
# =====================================================
echo "0 2 * * * $USER tar czf $BACKUP_DIR/stack-\$(date +\%Y\%m\%d).tar.gz -C $STACK_DIR ." | crontab -

# =====================================================
# Unattended upgrades
# =====================================================
dpkg-reconfigure --priority=low unattended-upgrades

# =====================================================
# Post-install check + QR-code
# =====================================================
echo "===================================================="
echo "🚀 Post-install check"
echo "===================================================="

echo "📦 Docker containers status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "🌐 Controle open poorten:"
for port in 8120 8121 8123 8129 8131 8132 8133 8134 8135 51820; do
    if ss -tuln | grep -q "$port"; then
        echo "Port $port open ✅"
    else
        echo "Port $port gesloten ❌"
    fi
done

echo "🔑 WireGuard status:"
wg show $WG_INTERFACE

if command -v qrencode &>/dev/null; then
    echo "📱 WireGuard QR-code voor client:"
    qrencode -t ansiutf8 < "$WG_CLIENT_CONF"
else
    echo "⚠️ qrencode niet geïnstalleerd, kan geen QR-code tonen"
fi

echo "🔌 Gedetecteerde USB-devices:"
echo "Zigbee: ${#ZIGBEE_DEVS[@]} ${ZIGBEE_DEVS[@]}"
echo "Z-Wave: ${#ZWAVE_DEVS[@]} ${ZWAVE_DEVS[@]}"
echo "BLE:    ${#BLE_DEVS[@]} ${BLE_DEVS[@]}"
echo "RF:     ${#RF_DEVS[@]} ${RF_DEVS[@]}"
echo "IR:     ${#IR_DEVS[@]} ${IR_DEVS[@]}"
echo "P1:     ${#P1_DEVS[@]} ${P1_DEVS[@]}"

IP=$(hostname -I | awk '{print $1}')
echo "🏠 Home Assistant:  http://${IP}:8123"
echo "🛠 IT-Tools:        http://${IP}:8135"
echo "📊 CrowdSec:        http://${IP}:8080"

echo "===================================================="
echo "✅ Installatie compleet!"