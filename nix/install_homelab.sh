#!/bin/bash
set -e

# ============================================
# Homelab setup installer - NixOS + Docker
# ============================================

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

# -------------------------------
# Kopieer configuration.nix
# -------------------------------
echo "=== COPY configuration.nix ==="
cp "$CONFIG_SRC" "$CONFIG_DEST"
echo "configuration.nix geplaatst in $CONFIG_DEST"

# -------------------------------
# Maak homelab folder als die niet bestaat
# -------------------------------
echo "=== CREATE HOMELAB FOLDER ==="
mkdir -p "$HOMELAB_DIR"

# -------------------------------
# Kopieer docker-compose.yml
# -------------------------------
echo "=== COPY docker-compose.yml ==="
cp "$COMPOSE_SRC" "$COMPOSE_DEST"
echo "docker-compose.yml geplaatst in $COMPOSE_DEST"

# -------------------------------
# Kopieer .env
# -------------------------------
echo "=== COPY .env ==="
cp "$ENV_SRC" "$ENV_DEST"
echo ".env geplaatst in $ENV_DEST"

# -------------------------------
# NixOS rebuild
# -------------------------------
echo "=== REBUILD NIXOS ==="
nixos-rebuild switch

echo ""
echo "====================================="
echo "Homelab setup klaar!"
echo "Ga naar $HOMELAB_DIR en start containers met:"
echo "docker-compose up -d"
echo "====================================="