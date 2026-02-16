#!/bin/bash
set -euo pipefail

# ============================
# Automatisch download en schrijf laatste NixOS minimal ISO naar USB
# ============================

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

# Input USB stick
if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 /dev/sdX"
    exit 1
fi
USB_DEV="$1"

# Waarschuwing
read -p "⚠️ Alle data op $USB_DEV wordt overschreven. Doorgaan? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 1
fi

# -------------------------------
# Detecteer laatste NixOS release (stable)
# -------------------------------
echo "=== Detecteer laatste NixOS release ==="
LATEST_PAGE=$(curl -s https://releases.nixos.org/nixos/)
LATEST_VERSION=$(echo "$LATEST_PAGE" | grep -oP 'nixos-[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -1)
if [[ -z "$LATEST_VERSION" ]]; then
    echo "Kan laatste release niet vinden."
    exit 1
fi
echo "Laatste NixOS release: $LATEST_VERSION"

# URLs voor minimal ISO
ISO_URL="https://releases.nixos.org/nixos/$LATEST_VERSION/nixos-minimal-x86_64-linux.iso"
ISO_SHA256_URL="$ISO_URL.sha256"
ISO_FILE="/tmp/nixos-minimal.iso"

# -------------------------------
# Download ISO
# -------------------------------
echo "=== Download ISO ==="
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
# Bepaal exacte ISO grootte
# -------------------------------
ISO_SIZE=$(stat -c%s "$ISO_FILE")
echo "ISO grootte: $ISO_SIZE bytes"

# -------------------------------
# Schrijf ISO naar USB stick
# -------------------------------
echo "=== Schrijf ISO naar $USB_DEV ==="
# Alles op USB wordt overschreven
sync
dd if="$ISO_FILE" of="$USB_DEV" bs=4M status=progress oflag=sync
sync

echo "✅ NixOS ISO is succesvol op $USB_DEV gezet."
echo "Je kunt nu van deze USB stick booten."