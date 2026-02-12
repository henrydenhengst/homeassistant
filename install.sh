#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK + WireGuard + DuckDNS + IT-TOOLS
# Debian 13 Minimal - Secure Plug & Play Setup
# =====================================================

set -e

# =====================================================
# Basis directories & log
# =====================================================
STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
IT_TOOLS_DIR="$STACK_DIR/it-tools"
LOG_FILE="$STACK_DIR/ha-install.log"
mkdir -p "$STACK_DIR" "$BACKUP_DIR" "$IT_TOOLS_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# =====================================================
# Laad .env bestand
# =====================================================
if [ ! -f "$STACK_DIR/.env" ]; then
    echo "❌ .env bestand ontbreekt in $STACK_DIR"
    exit 1
fi

export $(grep -v '^#' "$STACK_DIR/.env" | xargs)
chmod 600 "$STACK_DIR/.env"

# =====================================================
# Pre-checks: Disk, RAM, Root
# =====================================================
FREE_DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
if [[ $FREE_DISK_GB -lt 14 || $TOTAL_RAM_MB -lt 3000 ]]; then
    echo "❌ Onvoldoende systeembronnen."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "❌ Run als root"
    exit 1
fi

# =====================================================
# Netwerk configuratie
# =====================================================
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
NETWORK_FILE="/etc/systemd/network/10-${INTERFACE}-static.network"
[ -f "$NETWORK_FILE" ] && cp "$NETWORK_FILE" "$BACKUP_DIR/$(basename $NETWORK_FILE).bak.$(date +%Y%m%d_%H%M%S)"
[ -f /etc/resolv.conf ] && cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)"

systemctl stop dhcpcd NetworkManager 2>/dev/null || true
systemctl disable dhcpcd NetworkManager 2>/dev/null || true
systemctl enable systemd-networkd

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
ufw openssh-server usbutils fail2ban vim nano ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd unattended-upgrades \
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
# UFW + SSH + Fail2Ban
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 51820/udp
for port in {8120..8140}; do ufw allow ${port}/tcp; done
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

# Voeg automatisch containers toe afhankelijk van autodetect
add_container() {
    local name=$1 image=$2 port=$3 volume=$4 devices=$5
    cat >> "$STACK_DIR/docker-compose.yml" <<EOF
  $name:
    image: $image
    container_name: $name
    restart: unless-stopped
    ports: ["$port"]
    volumes: ["$volume"]
EOF
    if [ -n "$devices" ]; then
        echo "    devices:" >> "$STACK_DIR/docker-compose.yml"
        for d in $devices; do
            echo "      - $d" >> "$STACK_DIR/docker-compose.yml"
        done
    fi
}
# Voorbeeld: Zigbee, Z-Wave, BLE, RF, IR, P1
[ ${#ZIGBEE_DEVS[@]} -gt 0 ] && add_container "zigbee2mqtt" "koenkk/zigbee2mqtt" "8121:8080" "./zigbee2mqtt:/app/data" "${ZIGBEE_DEVS[@]}"
[ ${#ZWAVE_DEVS[@]} -gt 0 ] && add_container "zwavejs2mqtt" "zwavejs/zwavejs2mqtt" "8129:8091" "./zwavejs2mqtt:/usr/src/app/store" "${ZWAVE_DEVS[@]}"
[ ${#BLE_DEVS[@]} -gt 0 ] && add_container "ble2mqtt" "koenkk/ble2mqtt" "8131:8080" "./ble2mqtt:/app/data"
[ ${#RF_DEVS[@]} -gt 0 ] && add_container "rfxtrx" "docker-rfxtrx" "8132:8080" "./rfxtrx:/data"
[ ${#IR_DEVS[@]} -gt 0 ] && add_container "mqtt-ir" "mqtt-ir" "8133:8080" "./mqtt-ir:/data"
[ ${#P1_DEVS[@]} -gt 0 ] && add_container "p1monitor" "p1monitor" "8134:8080" "./p1monitor:/data"

# IT-Tools
add_container "it-tools" "corentinth/it-tools:latest" "8135:80" "./it-tools:/data"

docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# WireGuard setup
# =====================================================
apt install -y wireguard
umask 077
mkdir -p /etc/wireguard

wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
CLIENT_PRIV=$(cat /etc/wireguard/client_private.key)
CLIENT_PUB=$(cat /etc/wireguard/client_public.key)

cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
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

cat > "$STACK_DIR/wg-client.conf" <<EOF
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
# CrowdSec + dashboard
# =====================================================
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
apt install -y crowdsec crowdsec-firewall-bouncer crowdsec-ui
systemctl enable crowdsec crowdsec-ui
systemctl start crowdsec crowdsec-ui

# =====================================================
# Cron auto-backup
# =====================================================
echo "0 2 * * * $USER tar czf $BACKUP_DIR/stack-\$(date +\%Y\%m\%d).tar.gz -C $STACK_DIR ." | crontab -

# =====================================================
# Unattended upgrades
# =====================================================
dpkg-reconfigure --priority=low unattended-upgrades

# =====================================================
# Post-install overzicht
# =====================================================
IP=$(hostname -I | awk '{print $1}')
echo "===================================================="
echo "INSTALLATIE VOLTOOID 🎉"
echo "Home Assistant:  http://${IP}:8123"
echo "DuckDNS:        https://${DUCKDNS_SUB}.duckdns.org"
echo "WireGuard client config: $STACK_DIR/wg-client.conf"
echo "CrowdSec dashboard:      http://${IP}:8080"
echo "Backup directory:        $BACKUP_DIR"
echo "Zigbee devices:          ${#ZIGBEE_DEVS[@]}"
echo "Z-Wave devices:          ${#ZWAVE_DEVS[@]}"
echo "BLE devices:             ${#BLE_DEVS[@]}"
echo "RF devices:              ${#RF_DEVS[@]}"
echo "IR devices:              ${#IR_DEVS[@]}"
echo "Smart Meter (P1) devices:${#P1_DEVS[@]}"
echo "IT-Tools web interface:   http://${IP}:8135"
echo "===================================================="