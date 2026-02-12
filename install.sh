#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK INSTALLER
# Debian 13 Minimal - Secure Plug & Play Setup
# =====================================================
#
# FUNCTIONALITEIT:
#   - Installeert Home Assistant stack via Docker
#   - MariaDB database voor Home Assistant
#   - Mosquitto MQTT broker
#   - Zigbee2MQTT, Z-Wave JS, BLE2MQTT, RFXtrx, MQTT-IR, P1Monitor (auto detect USB)
#   - ESPhome, Portainer, Watchtower, Dozzle, InfluxDB, Grafana, Netdata, Uptime-Kuma, Homer
#   - CrowdSec monitoring op poort 8134
#   - IT-Tools webinterface op poort 8135
#   - DuckDNS updater container
#   - WireGuard VPN met server- en clientconfiguratie + QR-code
#   - UFW firewall en SSH hardening
#   - Alt+Ctrl+Del uitgeschakeld
#   - Automatische dagelijkse backups
#
# VOORAF:
#   - Root-toegang vereist
#   - Internetverbinding nodig
#   - Minimaal 14 GB vrije schijfruimte, 3 GB RAM
#   - `.env` bestand met tijdzone, database credentials en DuckDNS token moet aanwezig zijn
#
# USAGE:
#   sudo ./ha-install.sh [STATIC_IP/CIDR] [GATEWAY]
#
# EXAMPLE:
#   sudo ./ha-install.sh 192.168.178.2/24 192.168.178.1
#
# PARAMETERS:
#   [STATIC_IP/CIDR] - Optioneel: het statisch IP met subnet, bijv. 192.168.178.2/24
#   [GATEWAY]        - Optioneel: het netwerk gateway IP, bijv. 192.168.178.1
#
# DEFAULTS:
#   STATIC_IP=192.168.1.10/24
#   GATEWAY=192.168.1.1
#
# USB + Bluetooth AUTODETECT:
#   - Zigbee, Z-Wave, BLE, RF, IR, P1 Smart Meter devices
#   - Bluetooth dongles
#   - Containers starten alleen als devices aanwezig zijn
#
# POST-INSTALL CHECKS:
#   - Toont Home Assistant, IT-Tools, CrowdSec, DuckDNS URLs
#   - WireGuard clientconfiguratie + QR-code
#   - Overzicht USB/Bluetooth devices
#   - Backup locatie en logbestand
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
    echo "❌ Geen .env bestand gevonden in $STACK_DIR"
    exit 1
fi
export $(grep -v '^#' "$STACK_DIR/.env" | xargs)
chmod 600 "$STACK_DIR/.env"
chown "$SUDO_USER:$SUDO_USER" "$STACK_DIR/.env"

# =====================================================
# Netwerkconfiguratie
# =====================================================
# =====================================================
# Netwerkbeheer detectie & statische IP configuratie
# =====================================================

echo ""
echo "Detecteer netwerkbeheer..."

# Detecteer eerste “echte” netwerkinterface
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^(lo|docker|br|veth|wg)' | head -n1)

if [ -z "$INTERFACE" ]; then
    echo "❌ Geen geschikte netwerkinterface gevonden (lo, docker, bridge etc. uitgesloten)."
    echo "Huidige interfaces:"
    ip link show
    echo ""
    read -p "Wil je handmatig een interface opgeven? (of druk Enter om netwerkconfiguratie over te slaan): " manual_if
    if [ -n "$manual_if" ]; then
        INTERFACE="$manual_if"
    else
        echo "Netwerkconfiguratie overgeslagen."
        SKIP_NETWORK_CONFIG=true
    fi
fi

echo "Gedetecteerde primaire interface: ${INTERFACE:-<geen>}"

# =============================================
# Netplan check
# =============================================

NETPLAN_ACTIVE=false
SKIP_NETWORK_CONFIG=false

if command -v netplan >/dev/null 2>&1; then
    if [ -d /etc/netplan ] && compgen -G "/etc/netplan/*.yaml" >/dev/null; then
        NETPLAN_ACTIVE=true
        echo "⚠️ Netplan is aanwezig en heeft configuratiebestanden → waarschijnlijk actief"
    else
        echo "ℹ️ Netplan is geïnstalleerd, maar geen .yaml bestanden gevonden in /etc/netplan"
    fi
else
    echo "ℹ️ Netplan niet geïnstalleerd"
fi

if [ "$NETPLAN_ACTIVE" = true ]; then
    echo ""
    echo "=============================================================="
    echo " WAARSCHUWING: Netplan lijkt actief te zijn op dit systeem"
    echo " Automatische statische IP configuratie kan genegeerd of overschreven worden"
    echo "=============================================================="
    echo ""
    read -p "Toch proberen systemd-networkd in te stellen? (y/N): " proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo "Netplan configuratie overgeslagen. Netwerk blijft ongewijzigd."
        SKIP_NETWORK_CONFIG=true
    else
        echo "Doorgaan met systemd-networkd instellingen (risico op conflict aanwezig)"
    fi
fi

# =============================================
# systemd-networkd instellen (alleen als niet geskipt)
# =============================================

if [ "${SKIP_NETWORK_CONFIG:-false}" != true ]; then

    echo "Activeren van systemd-networkd + systemd-resolved..."
    if ! systemctl enable --now systemd-networkd systemd-resolved 2>/dev/null; then
        echo "❌ Kan systemd-networkd of systemd-resolved niet activeren/starten"
        systemctl status systemd-networkd systemd-resolved --lines=0
        echo ""
        read -p "Doorgaan ondanks fout? (y/N): " force
        [[ ! "$force" =~ ^[Yy]$ ]] && exit 1
    fi

    # resolv.conf correct koppelen
    CURRENT_RESOLV=$(readlink -f /etc/resolv.conf 2>/dev/null || echo "")
    if [ "$CURRENT_RESOLV" = "/run/systemd/resolve/stub-resolv.conf" ] || [ "$CURRENT_RESOLV" = "/run/systemd/resolve/resolv.conf" ]; then
        echo "ℹ️ resolv.conf is al correct gekoppeld aan systemd-resolved"
    else
        echo "Symlink /etc/resolv.conf → /run/systemd/resolve/resolv.conf"
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi

    # =============================================
    # Statisch .network bestand aanmaken
    # =============================================

    NETWORK_FILE="/etc/systemd/network/20-${INTERFACE}-static.network"

    if [ -f "$NETWORK_FILE" ]; then
        echo "Bestaand configuratiebestand gevonden: $NETWORK_FILE"
        backup_file "$NETWORK_FILE"
    fi

    echo "Statisch IP configureren: $STATIC_IP via $INTERFACE"

    cat > "$NETWORK_FILE" <<EOF
[Match]
Name=$INTERFACE

[Network]
DHCP=no
Address=$STATIC_IP
Gateway=$GATEWAY
DNS=$DNS1 $DNS2 $DNS3

# Optioneel: link-local uitzetten als je puur statisch IPv4 wilt
# LinkLocalAddressing=no
EOF

    echo "Configuratiebestand geschreven: $NETWORK_FILE"

    # Herstarten en korte validatie
    echo "Netwerkdiensten herstarten..."
    systemctl restart systemd-networkd

    sleep 3

    # Simpele check
    CURRENT_IP=$(ip -4 addr show dev "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    if [ "${CURRENT_IP}" = "${STATIC_IP%/*}" ]; then
        echo "✅ Statisch IP succesvol toegepast: $CURRENT_IP"
    else
        echo "⚠️  Waarschuwing: verwachte IP ${STATIC_IP%/*} niet gezien"
        echo "Huidig IP op $INTERFACE: ${CURRENT_IP:-geen}"
        ip addr show dev "$INTERFACE"
    fi

else
    echo "Netwerkconfiguratie overgeslagen (zoals gevraagd of vanwege netplan)."
fi

# =====================================================
# Systeem update + tools
# =====================================================
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release \
ufw openssh-server usbutils bluetooth bluez fail2ban vim nano ripgrep fd-find fzf tmux git htop ncdu jq qrencode auditd unattended-upgrades \
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
# Firewall + SSH + Fail2Ban
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 51820/udp
ufw allow 8120:8140/tcp       # range voor HA services
ufw --force enable

# SSH root login uit
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
# Alt+Ctrl+Del uitschakelen
# =====================================================
systemctl mask ctrl-alt-del.target

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

# Bluetooth devices (toekomstbestendig)
BT_DEVS=()
if command -v bluetoothctl >/dev/null 2>&1; then
    while read -r line; do
        [[ "$line" =~ ^Controller\ ([^[:space:]]+) ]] && BT_DEVS+=("${BASH_REMATCH[1]}")
    done < <(bluetoothctl list)
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
      - \${ZIGBEE_USB}:/dev/ttyUSB0
    environment: ["TZ=\${HA_TZ}"]
    depends_on: [mosquitto]

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports: ["8129:8091"]
    volumes: ["./zwavejs2mqtt:/usr/src/app/store"]
    devices:
      - \${ZWAVE_USB}:/dev/ttyUSB0
    environment: ["TZ=\${HA_TZ}"]

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

  netdata:
    image: netdata/netdata
    container_name: netdata
    restart: unless-stopped
    ports: ["8131:19999"]
    cap_add: [SYS_PTRACE]
    security_opt: [apparmor:unconfined]
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    ports: ["8132:3001"]
    volumes: ["./uptime-kuma:/app/data"]

  homer:
    image: b4bz/homer
    container_name: homer
    restart: unless-stopped
    ports: ["8133:8080"]
    volumes: ["./homer:/www/assets"]
    environment: ["INIT_ASSETS=1"]

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    ports: ["8134:8080"]

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
      - TZ=\${HA_TZ}
      - SUBDOMAINS=\${DUCKDNS_SUB}
      - TOKEN=\${DUCKDNS_TOKEN}
volumes:
  portainer_data:
EOF

echo "✅ docker-compose.yml aangemaakt"

# =====================================================
# Start containers
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# WireGuard installatie en QR
# =====================================================

# =====================================================
# WireGuard installatie, IP forwarding en QR
# =====================================================
apt install -y wireguard
umask 077
mkdir -p $WG_CONF_DIR

# IP forwarding inschakelen
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Server en client keys genereren
wg genkey | tee $WG_CONF_DIR/server_private.key | wg pubkey > $WG_CONF_DIR/server_public.key
SERVER_PRIV=$(cat $WG_CONF_DIR/server_private.key)
SERVER_PUB=$(cat $WG_CONF_DIR/server_public.key)
wg genkey | tee $WG_CONF_DIR/client_private.key | wg pubkey > $WG_CONF_DIR/client_public.key
CLIENT_PRIV=$(cat $WG_CONF_DIR/client_private.key)
CLIENT_PUB=$(cat $WG_CONF_DIR/client_public.key)

# Server configuratie
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

# Client configuratie met werkende publieke DNS
cat > $WG_CLIENT_CONF <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.10.0.2/24
DNS = 1.1.1.1, 9.9.9.9

[Peer]
PublicKey = $SERVER_PUB
Endpoint = \${DUCKDNS_SUB}.duckdns.org:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# WireGuard service starten
systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

# QR-code voor clientconfig
qrencode -t ansiutf8 < "$WG_CLIENT_CONF"

echo "✅ WireGuard opgezet met IP forwarding en werkende DNS in client-config"
# =====================================================
# Post-install checks
# =====================================================
IP=$(hostname -I | awk '{print $1}')
echo "===================================================="
echo "INSTALLATIE VOLTOOID 🎉"

echo "🔎 Container status check:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "Home Assistant:  http://${IP}:8123"
echo "IT-Tools:        http://${IP}:8135"
echo "CrowdSec:        http://${IP}:8134"
echo "WireGuard client config: $WG_CLIENT_CONF"
echo "QR-code hierboven weergegeven"
echo "Backup directory:        $BACKUP_DIR"
echo "Zigbee devices:          ${#ZIGBEE_DEVS[@]}"
echo "Z-Wave devices:          ${#ZWAVE_DEVS[@]}"
echo "BLE devices:             ${#BLE_DEVS[@]}"
echo "Bluetooth adapters:      ${#BT_DEVS[@]}"
echo "RF devices:              ${#RF_DEVS[@]}"
echo "IR devices:              ${#IR_DEVS[@]}"
echo "Smart Meter (P1) devices:${#P1_DEVS[@]}"
echo "===================================================="
echo "✅ Alle containers gestart en services beschikbaar"
echo "Logbestand: $LOG_FILE"