#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${SUDO_USER:-$(whoami)}"
HOMELAB_DIR="/srv/homelab"
REPO_URL="https://github.com/henrydenhengst/homeassistant.git"
REPO_DIR="$HOMELAB_DIR/homeassistant"

echo "===================================="
echo " Homelab Post Setup Script"
echo "===================================="

# ----------------------------
# Docker group check
# ----------------------------
echo ">>> Checking docker group membership"

if id -nG "$USER_NAME" | grep -qw docker; then
    echo "User $USER_NAME is in docker group ✅"
else
    echo "Adding $USER_NAME to docker group"
    usermod -aG docker "$USER_NAME"
fi

# ----------------------------
# Homelab directory
# ----------------------------
echo ">>> Ensuring homelab directory exists"
mkdir -p "$HOMELAB_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$HOMELAB_DIR"

# ----------------------------
# Docker service
# ----------------------------
echo ">>> Checking Docker binary"
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker niet gevonden ❌"
    exit 1
fi

echo ">>> Enabling Docker service"
systemctl enable docker || true

echo ">>> Starting Docker service"
systemctl start docker || true

sleep 2

echo ">>> Verifying Docker service"
if systemctl is-active --quiet docker; then
    echo "Docker draait ✅"
else
    echo "Docker start mislukt ❌"
    exit 1
fi

# ----------------------------
# Docker test container
# ----------------------------
echo ">>> Running Docker test container"
if docker run --rm hello-world >/dev/null 2>&1; then
    echo "Docker test container OK ✅"
else
    echo "Docker test container FAILED ❌"
fi

# ----------------------------
# Docker compose check
# ----------------------------
echo ">>> Checking Docker Compose plugin"
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose beschikbaar ✅"
else
    echo "Docker Compose ontbreekt ⚠"
fi

# ----------------------------
# Git check
# ----------------------------
echo ">>> Checking Git"
if ! command -v git >/dev/null 2>&1; then
    echo "Git niet gevonden → probeer installeren"
    nix-env -iA nixos.git || true
fi

# ----------------------------
# Repo ophalen
# ----------------------------
echo ">>> Preparing homelab repo"

if [ -d "$REPO_DIR/.git" ]; then
    echo "Repo bestaat al → pull latest"
    git -C "$REPO_DIR" pull
else
    echo "Cloning repo"
    git clone "$REPO_URL" "$REPO_DIR"
fi

chown -R "$USER_NAME":"$USER_NAME" "$HOMELAB_DIR"

# ----------------------------
# Docker compose start
# ----------------------------
echo ">>> Starting docker compose stack"

if [ -f "$REPO_DIR/docker-compose.yml" ] || [ -f "$REPO_DIR/compose.yml" ]; then
    cd "$REPO_DIR"
    docker compose up -d
    echo "Docker stack gestart ✅"
else
    echo "⚠ Geen docker-compose.yml gevonden"
fi

# ----------------------------
# Refresh docker group session
# ----------------------------
echo ">>> Refreshing docker group session"

if command -v loginctl >/dev/null 2>&1; then
    loginctl terminate-user "$USER_NAME" || true
else
    echo "Log opnieuw in voor docker group"
fi

echo ""
echo "===================================="
echo " DONE"
echo "===================================="
echo ""
echo "➡ Indien SSH disconnect → reconnect"
echo "➡ Controleer containers:"
echo "docker ps"
echo ""