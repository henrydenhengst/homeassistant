#!/bin/bash
set -euo pipefail

# === Config ===
ARCHIVE_BASE="https://cdimage.debian.org/cdimage/archive/12.13.0/amd64/iso-cd"
USB_DEVICE="/dev/sdb"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}📥 Download SHA256SUMS…${NC}"
wget -q -O SHA256SUMS "${ARCHIVE_BASE}/SHA256SUMS"

# Pak automatisch alleen de standaard netinst ISO (geen edu/mac)
ISO_BASENAME=$(grep -E "^([a-f0-9]{64})  debian-12.*-amd64-netinst\.iso$" SHA256SUMS | awk '{print $2}' | head -n1)
ISO_URL="${ARCHIVE_BASE}/${ISO_BASENAME}"

echo -e "${YELLOW}📥 Download ISO: $ISO_BASENAME${NC}"
if [ ! -f "$ISO_BASENAME" ]; then
    wget -O "$ISO_BASENAME" "$ISO_URL"
else
    echo -e "${YELLOW}⚠️ ISO bestaat al, overslaan downloaden${NC}"
fi

echo -e "\n${YELLOW}🔁 Controleer checksum…${NC}"
sha256sum -c --ignore-missing SHA256SUMS

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Checksum mismatch! Stoppen.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Checksum klopt${NC}"
fi

# Controleer pv
echo -e "\n${YELLOW}🔧 Controleren of pv geïnstalleerd is…${NC}"
if ! command -v pv >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 pv niet gevonden, installeren…${NC}"
    sudo apt update
    sudo apt install -y pv
fi

# Bevestiging met nieuwe tekst
echo -e "\n${RED}⚠️ ALLES OP $USB_DEVICE WORDT GEWIST!${NC}"
echo -n "${RED}Typ EXACT 'SCHRIJF-NU' om door te gaan: ${NC}"
read -r confirm
if [[ "$confirm" != "SCHRIJF-NU" ]]; then
    echo -e "${YELLOW}❌ Afgebroken${NC}"
    exit 1
fi

# Unmount USB
echo -e "\n${YELLOW}🔌 Unmount USB…${NC}"
sudo umount "${USB_DEVICE}"* 2>/dev/null || true

# Schrijf ISO
echo -e "\n${GREEN}🚀 Schrijven naar USB…${NC}"
sudo pv "$ISO_BASENAME" | sudo dd of="$USB_DEVICE" bs=4M status=progress conv=fdatasync
sync

echo -e "\n${GREEN}🎉 Klaar! Debian 12 USB gemaakt op $USB_DEVICE${NC}"
echo -e "${YELLOW}Gebruik om veilig uit te werpen: sudo eject $USB_DEVICE${NC}"
