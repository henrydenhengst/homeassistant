#!/bin/bash

# 1. SSD Partitioneren (MBR/Legacy BIOS)
echo "Stap 1: SSD partitioneren op /dev/sda..."
sudo parted /dev/sda -- mklabel msdos
sudo parted /dev/sda -- mkpart primary ext4 1MiB 100%
sudo parted /dev/sda -- set 1 boot on

# 2. Formatteren naar ext4 met het label 'nixos'
echo "Stap 2: SSD formatteren..."
sudo mkfs.ext4 -L nixos /dev/sda1

# 3. Mounten naar /mnt (Dit dwingt de installatie naar de SSD)
echo "Stap 3: SSD mounten op /mnt..."
sudo mount /dev/disk/by-label/nixos /mnt

# 4. Hardware configuratie genereren op basis van de SSD
echo "Stap 4: Hardware configuratie genereren..."
sudo nixos-generate-config --root /mnt

# 5. Mappenstructuur voorbereiden
echo "Stap 5: Config mappen aanmaken..."
sudo mkdir -p /mnt/etc/nixos

echo "-------------------------------------------------------"
echo "KLAAR: Je SSD is nu gemount op /mnt."
echo "Je kunt nu 'install_homelab.sh' uitvoeren."
echo "Zorg dat je script de config naar /mnt/etc/nixos schrijft!"
echo "-------------------------------------------------------"
