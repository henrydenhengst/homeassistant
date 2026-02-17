#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "NixOS Safe Disk Setup Helper"
echo "======================================"

echo
echo "Beschikbare disks:"
lsblk -d -o NAME,SIZE,MODEL
echo

read -rp "Welke disk wil je gebruiken? (bijv. sda): " DISK
DISK="/dev/$DISK"

if [ ! -b "$DISK" ]; then
  echo "Disk bestaat niet!"
  exit 1
fi

echo
echo "⚠ ALLE DATA OP $DISK WORDT VERWIJDERD!"
read -rp "Type YES om door te gaan: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Afgebroken."
  exit 1
fi

echo
echo "=== Partities maken (MBR / BIOS) ==="

parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary ext4 1MiB 20GiB
parted -s "$DISK" mkpart primary ext4 20GiB 100%

ROOT="${DISK}1"
HOME="${DISK}2"

echo
echo "=== Filesystems maken ==="
mkfs.ext4 -F "$ROOT"
mkfs.ext4 -F "$HOME"

echo
echo "=== Mounten ==="
mount "$ROOT" /mnt
mkdir -p /mnt/home
mount "$HOME" /mnt/home

echo
echo "=== Swapfile maken (2GB) ==="
fallocate -l 2G /mnt/swapfile || dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile

echo
echo "=== Config genereren ==="
nixos-generate-config --root /mnt

echo
echo "======================================"
echo "✅ Disk setup klaar!"
echo
echo "Volgende stappen:"
echo "1. vim /mnt/etc/nixos/configuration.nix"
echo "2. nixos-install"
echo "3. reboot"
echo "======================================"