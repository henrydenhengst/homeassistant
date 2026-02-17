#!/bin/bash
set -e

# ============================================
# Homelab setup installer - NixOS + Docker (SSD Versie)
# ============================================

# Logging - Schrijf naar de SSD zodat het bewaard blijft
LOG_DIR="/mnt/srv/homelab"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# Bronlocaties
CONFIG_SRC="./configuration.nix"
COMPOSE_SRC="./docker-compose.yml"
ENV_SRC="./.env"

# Doelen (WIJZIGING: Gebruik /mnt voor de SSD installatie)
CONFIG_DEST="/mnt/etc/nixos/configuration.nix"
HOMELAB_DIR="/mnt/srv/homelab"
COMPOSE_DEST="$HOMELAB_DIR/docker-compose.yml"
ENV_DEST="$HOMELAB_DIR/.env"

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

echo "======================================"
echo "  Homelab SSD installer starting..."
echo "  Target: /dev/sda (via /mnt)"
echo "======================================"

# -------------------------------
# Kopieer configuration.nix
# -------------------------------
echo "=== COPY configuration.nix ==="
cp "$CONFIG_SRC" "$CONFIG_DEST"
echo "configuration.nix geplaatst in $CONFIG_DEST"

# -------------------------------
# Detect USB dongles
# -------------------------------
echo "=== DETECT USB DEVICES ==="
# We zoeken op het huidige live systeem
ZIGBEE=$(ls /dev/serial/by-id/*Zigbee* 2>/dev/null | head -n1 || true)
BLE=$(ls /dev/serial/by-id/*USB* 2>/dev/null | grep -v Zigbee | head -n1 || true)

# -------------------------------
# Update / maak .env
# -------------------------------
echo "=== CREATE / UPDATE .env ==="
cp "$ENV_SRC" "$ENV_DEST"
sed -i "s|^ZIGBEE2MQTT_DEVICE=.*|ZIGBEE2MQTT_DEVICE=$ZIGBEE|" "$ENV_DEST" || echo "ZIGBEE2MQTT_DEVICE=$ZIGBEE" >> "$ENV_DEST"
sed -i "s|^BLE2MQTT_DEVICE=.*|BLE2MQTT_DEVICE=$BLE|" "$ENV_DEST" || echo "BLE2MQTT_DEVICE=$BLE" >> "$ENV_DEST"

# -------------------------------
# Kopieer docker-compose.yml
# -------------------------------
echo "=== COPY docker-compose.yml ==="
cp "$COMPOSE_SRC" "$COMPOSE_DEST"

# -------------------------------
# ECHTE INSTALLATIE NAAR SSD
# -------------------------------
echo "=== INSTALL NIXOS TO SSD ==="
# WIJZIGING: Gebruik nixos-install ipv nixos-rebuild switch
nixos-install --no-root-passwd

echo ""
echo "====================================="
echo "Homelab setup op SSD klaar!"
echo "Logfile: $LOG_FILE"
echo "1. Haal de USB-stick eruit."
echo "2. Type: reboot"
echo "3. Na de reboot kun je de Docker stack starten in /srv/homelab"
echo "====================================="
