#!/bin/bash
set -e

# ============================================
# Homelab setup installer - NixOS + Docker (SSD Versie)
# ============================================

# Logging
LOG_DIR="/mnt/srv/homelab"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# Bronlocaties
CONFIG_SRC="./configuration.nix"
COMPOSE_SRC="./docker-compose.yml"
ENV_SRC="./.env"

# Doelen
CONFIG_DEST="/mnt/etc/nixos/configuration.nix"
HOMELAB_DIR="/mnt/srv/homelab"
COMPOSE_DEST="$HOMELAB_DIR/docker-compose.yml"
ENV_DEST="$HOMELAB_DIR/.env"

echo "======================================"
echo "  Homelab SSD installer starting..."
echo "======================================"

# 1. Config kopiëren
cp "$CONFIG_SRC" "$CONFIG_DEST"

# 2. USB detectie (Zigbee/BLE)
ZIGBEE=$(ls /dev/serial/by-id/*Zigbee* 2>/dev/null | head -n1 || true)
BLE=$(ls /dev/serial/by-id/*USB* 2>/dev/null | grep -v Zigbee | head -n1 || true)

# 3. .env en docker-compose kopiëren naar SSD
cp "$ENV_SRC" "$ENV_DEST"
cp "$COMPOSE_SRC" "$COMPOSE_DEST"

# 4. .env patchen met de juiste USB poorten
sed -i "s|^ZIGBEE2MQTT_DEVICE=.*|ZIGBEE2MQTT_DEVICE=$ZIGBEE|" "$ENV_DEST"
sed -i "s|^BLE2MQTT_DEVICE=.*|BLE2MQTT_DEVICE=$BLE|" "$ENV_DEST"

# 5. ECHTE INSTALLATIE
echo "=== INSTALLEREN NAAR SSD (Dit kan even duren) ==="
nixos-install --no-root-passwd

# 6. Rechten goedzetten voor na de reboot
chown -R 1000:1000 "$HOMELAB_DIR"

echo "====================================="
echo "Klaar! Doe nu het volgende:"
echo "1. Type: reboot"
echo "2. Na herstart, log in als 'homelab'"
echo "3. Type: cd /srv/homelab && sudo docker compose up -d"
echo "====================================="
