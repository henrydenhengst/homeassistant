#!/bin/bash
set -euo pipefail

# ============================
# Eenvoudig: schrijf NixOS minimal ISO naar USB
# ============================

ISO_URL="https://releases.nixos.org/nixos/25.11/nixos-25.11.5776.6c5e707c6b53/nixos-minimal-25.11.5776.6c5e707c6b53-x86_64-linux.iso"
ISO_FILE="/tmp/nixos-25.11-minimal.iso"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Run as root"
    exit 1
fi

# USB-stick als argument
if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 /dev/sdX"
    exit 1
fi
USB_DEV="$1"

if [[ ! -b "$USB_DEV" ]]; then
    echo "❌ $USB_DEV bestaat niet of is geen block device"
    exit 1
fi

# Download ISO als die nog niet lokaal is
if [[ ! -f "$ISO_FILE" ]]; then
    echo "📥 Download ISO..."
    wget -O "$ISO_FILE" "$ISO_URL"
fi

# Controleer bestand
if [[ ! -f "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then
    echo "❌ ISO download mislukt!"
    exit 1
fi

# Waarschuwing en bevestiging
read -p "⚠️ Alle data op $USB_DEV wordt overschreven. Doorgaan? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 1
fi

# Unmount USB
echo "💿 Unmount USB..."
umount ${USB_DEV}?* 2>/dev/null || true

# Schrijf ISO
echo "💾 Schrijf ISO naar $USB_DEV..."
dd if="$ISO_FILE" of="$USB_DEV" bs=16M status=progress conv=fsync
sync
blockdev --flushbufs "$USB_DEV" || true

echo "✅ Klaar! Je kunt nu van deze USB stick booten."
