#!/bin/bash
# =====================================================
# STABIEL HOMELAB INSTALLER - Debian 13 met firmware
# =====================================================
set -e

STACK_DIR="/opt/homelab"
ENV_FILE="$STACK_DIR/.env"

echo "=== SYSTEEM CHECK ==="
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# -------------------------------
# Repos controleren / non-free firmware toevoegen
# -------------------------------
echo "=== ADD NON-FREE FIRMWARE REPOS ==="
if ! grep -q "non-free-firmware" /etc/apt/sources.list; then
    sed -i 's/\(main\)/\1 contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi

# -------------------------------
# Basis firmware installeren (Zigbee / Bluetooth / WiFi)
# -------------------------------
echo "=== INSTALL FIRMWARE ==="
apt update
apt install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree \
               firmware-realtek firmware-iwlwifi bluez-firmware \
               ca-certificates curl gnupg lsb-release

# -------------------------------
# Docker (officiële repo)
# -------------------------------
echo "=== INSTALL DOCKER ==="
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian \
$(. /etc/os-release && echo $VERSION_CODENAME) stable" \
> /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl restart docker

# -------------------------------
# Folder structuur
# -------------------------------
echo "=== CREATE FOLDERS ==="
mkdir -p homeassistant mariadb mosquitto portainer

# -------------------------------
# .env
# -------------------------------
echo "=== CREATE ENV ==="
cat > "$ENV_FILE" <<EOF
TZ=Europe/Amsterdam
MYSQL_ROOT_PASSWORD=homeassistantroot
MYSQL_DATABASE=homeassistant
MYSQL_USER=homeassistant
MYSQL_PASSWORD=homeassistant
EOF

# -------------------------------
# Docker Compose
# -------------------------------
echo "=== CREATE DOCKER COMPOSE ==="
cat > docker-compose.yml <<'EOF'
services:

  mariadb:
    image: mariadb:11
    container_name: mariadb
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto:/mosquitto

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    privileged: true
    env_file: .env
    volumes:
      - ./homeassistant:/config
    depends_on:
      - mariadb
      - mosquitto

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer:/data
EOF

# -------------------------------
# Start stack
# -------------------------------
echo "=== START STACK ==="
docker compose up -d

echo ""
echo "====================================="
echo "HOME ASSISTANT: http://SERVER-IP:8123"
echo "PORTAINER: http://SERVER-IP:9000"
echo "====================================="
echo "⚠️ USB dongles (Zigbee / Bluetooth) toevoegen later na test van basis stack."