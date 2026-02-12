#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT HOMELAB STACK + WireGuard + DuckDNS + QR + IT-TOOLS
# Debian 13 Minimal - Secure, self-healing, run-once
# =====================================================

set -e
STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
IT_TOOLS_DIR="$STACK_DIR/it-tools"
LOG_FILE="$HOME/ha-install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "INSTALLATIE START $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# =====================================================
# Pre-checks
# =====================================================
MIN_DISK_GB=14
MIN_RAM_MB=3000
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
# Maak directories
# =====================================================
mkdir -p "$STACK_DIR" "$BACKUP_DIR" "$IT_TOOLS_DIR"

# =====================================================
# Installeer basis tools en Docker
# =====================================================
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release \
ufw fail2ban vim nano htop jq tmux docker.io docker-compose unzip auditd unattended-upgrades qrencode

# =====================================================
# UFW + SSH
# =====================================================
ufw default deny incoming
ufw default allow outgoing
ufw allow 51820/udp    # WireGuard
for port in {8120..8140}; do ufw allow ${port}/tcp; done
ufw allow 22/tcp
ufw --force enable

sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
systemctl restart ssh
systemctl enable fail2ban

# =====================================================
# Laad .env (handmatig maken door gebruiker)
# =====================================================
ENV_FILE="$STACK_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Maak eerst $ENV_FILE met HA/MariaDB/DUCKDNS variabelen"
    exit 1
fi
export $(grep -v '^#' "$ENV_FILE" | xargs)
chmod 600 "$ENV_FILE"

# =====================================================
# USB autodetect (optioneel)
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
# Docker Compose file
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

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports: ["8135:80"]
    volumes:
      - ./it-tools:/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    command: --cleanup --schedule "0 0 4 * * *"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

# Voeg USB containers toe
[[ ${#ZIGBEE_DEVS[@]} -gt 0 ]] && echo "  # Zigbee container detected, voeg toe in compose"
[[ ${#ZWAVE_DEVS[@]} -gt 0 ]] && echo "  # Z-Wave container detected, voeg toe in compose"

# =====================================================
# WireGuard installatie
# =====================================================
WG_DIR="/etc/wireguard"
WG_IF="wg0"
WG_PORT=51820
mkdir -p $WG_DIR
umask 077
wg genkey | tee $WG_DIR/server_private.key | wg pubkey > $WG_DIR/server_public.key
wg genkey | tee $WG_DIR/client_private.key | wg pubkey > $WG_DIR/client_public.key

SERVER_PRIV=$(cat $WG_DIR/server_private.key)
SERVER_PUB=$(cat $WG_DIR/server_public.key)
CLIENT_PRIV=$(cat $WG_DIR/client_private.key)
CLIENT_PUB=$(cat $WG_DIR/client_public.key)

cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = 10.10.0.1/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV
PostUp = ufw route allow in on $WG_IF out on $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1); iptables -t nat -A POSTROUTING -o $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1) -j MASQUERADE
PostDown = ufw route delete allow in on $WG_IF out on $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1); iptables -t nat -D POSTROUTING -o $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1) -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.10.0.2/32
EOF

cat > $STACK_DIR/wg-client.conf <<EOF
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

systemctl enable wg-quick@$WG_IF
systemctl start wg-quick@$WG_IF

# =====================================================
# Start Docker containers
# =====================================================
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# =====================================================
# Health Check Script
# =====================================================
cat > /usr/local/bin/ha-health-check.sh <<'EOF'
#!/bin/bash
FAILED=0
for c in homeassistant mariadb mosquitto; do
    docker ps | grep -q $c || FAILED=1
done
[ $FAILED -eq 1 ] && docker compose -f $HOME/home-assistant/docker-compose.yml up -d
EOF
chmod +x /usr/local/bin/ha-health-check.sh
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/ha-health-check.sh") | crontab -

# =====================================================
# Disk Guard
# =====================================================
cat > /usr/local/bin/disk-guard.sh <<'EOF'
#!/bin/bash
THRESHOLD=90
USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
[ "$USAGE" -gt "$THRESHOLD" ] && docker system prune -af
EOF
chmod +x /usr/local/bin/disk-guard.sh
(crontab -l 2>/dev/null; echo "30 3 * * * /usr/local/bin/disk-guard.sh") | crontab -

# =====================================================
# Cron backup
# =====================================================
(crontab -l 2>/dev/null; echo "0 2 * * * tar czf $BACKUP_DIR/stack-\$(date +\%Y\%m\%d).tar.gz -C $STACK_DIR .") | crontab -

# =====================================================
# Post-install overzicht
# =====================================================
IP=$(hostname -I | awk '{print $1}')
echo "===================================================="
echo "INSTALLATIE VOLTOOID 🎉"
echo "Home Assistant:  http://${IP}:8123"
echo "DuckDNS:        https://${DUCKDNS_SUB}.duckdns.org"
echo "WireGuard client config: $STACK_DIR/wg-client.conf"
echo "IT-Tools web interface:  http://${IP}:8135"
echo "Backup directory:       $BACKUP_DIR"
echo "===================================================="