#!/bin/bash
# =====================================================
# Script: write-debian12-iso-pv.sh
# Purpose: Veilig schrijven van Debian 12 ISO naar USB
#          met progress bar via pv
# Author: ChatGPT
# =====================================================

set -euo pipefail

# --- Functie: detecteer USB-schijven ---
detect_usb() {
    echo "🔍 Detecteer USB-apparaten..."
    lsblk -ndo NAME,SIZE,TYPE,MODEL | grep disk
    echo ""
}

# --- Selecteer USB-schijf ---
select_usb() {
    detect_usb
    read -p "Typ de apparaatnaam van de USB (bijv. sdb): " usbname
    USB_DEVICE="/dev/$usbname"
    if [[ ! -b "$USB_DEVICE" ]]; then
        echo "❌ Fout: $USB_DEVICE bestaat niet."
        exit 1
    fi
}

# --- Configuratie ---
ISO_PATH="$1"          # Pad naar Debian 12 ISO
BLOCK_SIZE="4M"        # Blokgrootte voor pv/dd
SYNC_AFTER="true"      # flush cache na schrijven

# --- Check ISO ---
if [[ -z "$ISO_PATH" ]]; then
    echo "Gebruik: $0 /pad/naar/debian-12.iso"
    exit 1
fi

if [[ ! -f "$ISO_PATH" ]]; then
    echo "❌ Fout: ISO bestand bestaat niet: $ISO_PATH"
    exit 1
fi

# --- Controleer of pv geïnstalleerd is ---
if ! command -v pv &> /dev/null; then
    echo "ℹ️ pv niet gevonden, installeren..."
    sudo apt update && sudo apt install -y pv
fi

# --- Kies USB ---
select_usb

# --- Waarschuwing ---
echo "⚠️  Alles op $USB_DEVICE wordt overschreven!"
read -p "Type 'YES' om door te gaan: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Afgebroken."
    exit 1
fi

# --- Unmount USB indien gemount ---
echo "🔌 Controleren of $USB_DEVICE gemount is..."
MOUNTED_PARTS=$(lsblk -lnp "$USB_DEVICE" | awk '$7!="" {print $7}')
if [[ -n "$MOUNTED_PARTS" ]]; then
    echo "💡 Unmount gemounte partities:"
    echo "$MOUNTED_PARTS"
    for mnt in $MOUNTED_PARTS; do
        sudo umount "$mnt"
    done
fi

# --- Write ISO to USB via pv ---
echo "📀 Schrijven van $ISO_PATH naar $USB_DEVICE met progress bar..."
sudo pv "$ISO_PATH" | sudo dd of="$USB_DEVICE" bs="$BLOCK_SIZE" oflag=sync status=none

# --- Flush caches (optioneel) ---
if [[ "$SYNC_AFTER" == "true" ]]; then
    echo "💾 Synchroniseren van schijfcache..."
    sync
fi

echo "✅ Klaar! Debian 12 ISO is veilig op $USB_DEVICE geschreven."