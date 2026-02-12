#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK
# FIXED WORKING VERSION
# =====================================================

set -e

LOG_FILE="$HOME/ha-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "===================================================="

STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"

WG_PORT=51820
WG_INTERFACE="wg0"
WG_CONF_DIR="/etc/wireguard"
WG_CLIENT_CONF="$STACK_DIR/wg-client.conf"

# ==============================
# ROOT CHECK
# ==============================
if [[ $EUID -ne 0 ]]; then
   echo "❌ Run als root."
   exit 1
fi

# ==============================
# LOAD .env (veilig)
# ==============================
if [ ! -f "$STACK_DIR/.env" ]; then
    echo "❌ Geen .env bestand"
    exit 1
fi

set -a
source "$STACK_DIR/.env"
set +a

chmod 600 "$STACK_DIR/.env"

# ==============================
# SYSTEM UPDATE
# ==============================
apt update
apt upgrade -y
apt install -y curl ca-certificates gnupg lsb-release ufw \
               fail2ban qrencode unattended-upgrades \
               wireguard iptables

# ==============================
# DOCKER INSTALL
# ==============================
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
 | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# ==============================
# FIREWALL (MINIMAAL)
# ==============================
ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 8123/tcp
ufw allow 8120/tcp
ufw allow 8135/tcp
ufw allow 51820/udp

ufw --force enable

# ==============================
# DIRECTORIES
# ==============================
mkdir -p "$STACK_DIR"/{homeassistant,mariadb,mosquitto,it-tools}
mkdir -p "$BACKUP_DIR"

# ==============================
# DOCKER COMPOSE
# ==============================
cat > "$STACK_DIR/docker-compose.yml" <<EOF
services:

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
    volumes:
      - ./mosquitto:/mosquitto

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=${HA_TZ}
    volumes:
      - ./homeassistant:/config
    depends_on:
      - mariadb
      - mosquitto

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports:
      - "8135:80"

EOF

cd "$STACK_DIR"
docker compose up -d

# ==============================
# ENABLE IP FORWARDING (WG FIX)
# ==============================
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system

# ==============================
# WIREGUARD SETUP
# ==============================
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
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.10.0.2/32
EOF

cat > $WG_CLIENT_CONF <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.10.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${DUCKDNS_SUB}.duckdns.org:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

# ==============================
# CRON BACKUP FIXED
# ==============================
(crontab -l 2>/dev/null; echo "0 2 * * * tar czf $BACKUP_DIR/stack-\$(date +\%Y\%m\%d).tar.gz -C $STACK_DIR .") | crontab -

# ==============================
# DONE
# ==============================
IP=$(hostname -I | awk '{print $1}')

echo "===================================================="
echo "INSTALLATIE VOLTOOID"
echo "===================================================="
echo "Home Assistant:  http://${IP}:8123"
echo "IT-Tools:        http://${IP}:8135"
echo "WireGuard config: $WG_CLIENT_CONF"
echo "===================================================="