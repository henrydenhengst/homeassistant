#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "Homelab Bootstrap"
echo "======================================"

REPO_URL="https://github.com/henrydenhengst/homeassistant.git"
TARGET_DIR="/srv/homelab/homeassistant"
INSTALL_SCRIPT="install.sh"   # <-- pas aan indien nodig

echo
echo "=== Checks ==="

if ! command -v git >/dev/null; then
  echo "Git niet gevonden → installeer..."
  sudo nix-env -iA nixos.git || sudo nix profile install nixpkgs#git
fi

if ! command -v docker >/dev/null; then
  echo "⚠ Docker lijkt niet geïnstalleerd (controleer configuration.nix)"
fi

echo
echo "=== Homelab directories ==="
sudo mkdir -p /srv/homelab
sudo chown -R "$USER":"$USER" /srv/homelab

echo
echo "=== Repo ophalen ==="

if [ -d "$TARGET_DIR/.git" ]; then
  echo "Repo bestaat al → update"
  git -C "$TARGET_DIR" pull
else
  echo "Repo clonen"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

echo
echo "=== Install script zoeken ==="

if [ ! -f "$TARGET_DIR/$INSTALL_SCRIPT" ]; then
  echo "❌ Install script niet gevonden: $INSTALL_SCRIPT"
  echo "Controleer naam in script!"
  exit 1
fi

chmod +x "$TARGET_DIR/$INSTALL_SCRIPT"

echo
echo "=== Install script starten ==="
cd "$TARGET_DIR"
./"$INSTALL_SCRIPT"

echo
echo "======================================"
echo "✅ Homelab bootstrap klaar"
echo "======================================"