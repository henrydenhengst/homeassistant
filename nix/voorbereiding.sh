#!/bin/bash

# 1. Partitionering (Maakt een eenvoudige MBR tabel met 1 partitie)
echo "Schijf partitioneren..."
parted /dev/sda -- mklabel msdos
parted /dev/sda -- mkpart primary ext4 1MiB 100%
parted /dev/sda -- set 1 boot on

# 2. Formatteren
echo "SSD formatteren naar ext4..."
mkfs.ext4 -L nixos /dev/sda1

# 3. Mounten naar /mnt (Cruciaal om tmpfs te vermijden!)
echo "SSD mounten op /mnt..."
mount /dev/disk/by-label/nixos /mnt

# 4. Genereren van de basis hardware configuratie
echo "Hardware configuratie genereren..."
nixos-generate-config --root /mnt

# 5. Je eigen configuratie kopiëren
# Zorg dat je aangepaste configuration.nix in de huidige map staat
echo "Jouw configuration.nix overzetten..."
cp ./configuration.nix /mnt/etc/nixos/configuration.nix

# 6. De echte installatie naar schijf
echo "NixOS installeren op de SSD..."
nixos-install --no-root-passwd

echo "Installatie voltooid! Je kunt nu 'reboot' typen."
