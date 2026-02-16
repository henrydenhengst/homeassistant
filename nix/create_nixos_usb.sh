#!/bin/bash
set -euo pipefail

# ============================
# Download NixOS minimal ISO en schrijf naar USB
# ============================

# Default waarden
ISO_URL="https://releases.nixos.org/nixos/latest/nixos-minimal-x86_64-linux.iso"
ISO_SHA256_URL="${ISO_URL}.sha256"
ISO_FILE="/tmp/nixos-minimal.iso"

# Input USB stick
if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 /dev/sdX"
    exit 1
fi

USB_DEV="$1"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

# Waarschuwing
read -p "⚠️ Alle data op $USB_DEV wordt overschreven. Doorgaan? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 1
fi

# -------------------------------
# Download ISO
# -------------------------------
echo "=== Download NixOS ISO ==="
curl -L -o "$ISO_FILE" "$ISO_URL"

# -------------------------------
# Download en controleer SHA256
# -------------------------------
echo "=== Controleer SHA256 ==="
ISO_SHA256=$(curl -s "$ISO_SHA256_URL" | awk '{print $1}')
CALC_SHA256=$(sha256sum "$ISO_FILE" | awk '{print $1}')

if [[ "$ISO_SHA256" != "$CALC_SHA256" ]]; then
    echo "SHA256 mismatch! Download kan corrupt zijn."
    exit 1
fi
echo "SHA256 checksum correct."

# -------------------------------
# Schrijf ISO naar USB met dd
# -------------------------------
echo "=== Schrijf ISO naar $USB_DEV ==="
# Sync om buffer te flushen
sync
dd if="$ISO_FILE" of="$USB_DEV" bs=4M status=progress oflag=sync
sync

echo "✅ NixOS ISO is op $USB_DEV gezet."
echo "Je kunt nu van deze USB stick booten."