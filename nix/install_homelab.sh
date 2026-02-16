#!/bin/bash
set -e

# ============================================
# Homelab setup installer - NixOS + Docker
# ============================================

# Logging
LOG_FILE="/srv/homelab/install.log"
mkdir -p /srv/homelab
exec > >(tee -a "$LOG_FILE") 2>&1

# Locaties van je bestanden (pas aan als anders)
CONFIG_SRC="./configuration.nix"
COMPOSE_SRC="./docker-compose.yml"
ENV_SRC="./.env"

# Doelen
CONFIG_DEST="/etc/nixos/configuration.nix"
HOMELAB_DIR="/srv/homelab"
COMPOSE_DEST="$HOMELAB_DIR/docker-compose.yml"
ENV_DEST="$HOMELAB_DIR/.env"

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

echo "======================================"
echo "  Homelab setup installer starting..."
echo "  Log: $LOG_FILE"
echo "======================================"

# -------------------------------
# Kopieer configuration.nix
# -------------------------------
echo "=== COPY configuration.nix ==="
cp "$CONFIG_SRC" "$CONFIG_DEST"
echo "configuration.nix geplaatst in $CONFIG_DEST"

# -------------------------------
# Maak homelab folder
# -------------------------------
echo "=== CREATE HOMELAB FOLDER ==="
mkdir -p "$HOMELAB_DIR"
chown -R "${SUDO_USER:-$(whoami)}" "$HOMELAB_DIR"

# -------------------------------
# Detect USB dongles
# -------------------------------
echo "=== DETECT USB DEVICES ==="
ZIGBEE=$(ls /dev/serial/by-id/*Zigbee* 2>/dev/null | head -n1 || true)
BLE=$(ls /dev/serial/by-id/*USB* 2>/dev/null | grep -v Zigbee | head -n1 || true)

if [[ -z "$ZIGBEE" ]]; then
    echo "⚠️ Geen Zigbee dongle gevonden"
else
    echo "Zigbee detected: $ZIGBEE"
fi

if [[ -z "$BLE" ]]; then
    echo "⚠️ Geen BLE dongle gevonden"
else
    echo "BLE detected: $BLE"
fi

# -------------------------------
# Update / maak .env
# -------------------------------
echo "=== CREATE / UPDATE .env ==="
cp "$ENV_SRC" "$ENV_DEST"

# Update USB paden
sed -i "s|^ZIGBEE2MQTT_DEVICE=.*|ZIGBEE2MQTT_DEVICE=$ZIGBEE|" "$ENV_DEST" || echo "ZIGBEE2MQTT_DEVICE=$ZIGBEE" >> "$ENV_DEST"
sed -i "s|^BLE2MQTT_DEVICE=.*|BLE2MQTT_DEVICE=$BLE|" "$ENV_DEST" || echo "BLE2MQTT_DEVICE=$BLE" >> "$ENV_DEST"

echo ".env geplaatst en USB devices ingesteld"

# -------------------------------
# Kopieer docker-compose.yml
# -------------------------------
echo "=== COPY docker-compose.yml ==="
cp "$COMPOSE_SRC" "$COMPOSE_DEST"
echo "docker-compose.yml geplaatst in $COMPOSE_DEST"

# -------------------------------
# Rebuild NixOS
# -------------------------------
echo "=== REBUILD NIXOS ==="
nixos-rebuild switch

# -------------------------------
# Start Docker stack optioneel
# -------------------------------
read -p "Wil je direct de Docker stack starten? (y/N): " START_STACK
if [[ "$START_STACK" =~ ^[Yy]$ ]]; then
    echo "=== START DOCKER STACK ==="
    docker compose -f "$COMPOSE_DEST" up -d
    echo "Docker stack gestart!"
fi

echo ""
echo "====================================="
echo "Homelab setup klaar!"
echo "Logfile: $LOG_FILE"
echo "Ga naar $HOMELAB_DIR voor .env en docker-compose.yml"
echo "====================================="