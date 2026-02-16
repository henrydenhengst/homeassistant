#!/bin/bash
set -e

echo "=== SIMPLE STABLE HOMELAB INSTALL ==="

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

STACK_DIR="/opt/homelab"

mkdir -p $STACK_DIR
cd $STACK_DIR

echo "=== INSTALL DOCKER (OFFICIAL) ==="

apt update
apt install -y ca-certificates curl gnupg

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

echo "=== CREATE FOLDERS ==="

mkdir -p \
homeassistant \
mariadb \
mosquitto \
portainer

echo "=== CREATE ENV ==="

cat > .env <<EOF
TZ=Europe/Amsterdam
MYSQL_ROOT_PASSWORD=homeassistantroot
MYSQL_DATABASE=homeassistant
MYSQL_USER=homeassistant
MYSQL_PASSWORD=homeassistant
EOF

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

echo "=== START STACK ==="

docker compose up -d

echo ""
echo "====================================="
echo "HOME ASSISTANT:"
echo "http://SERVER-IP:8123"
echo ""
echo "PORTAINER:"
echo "http://SERVER-IP:9000"
echo "====================================="