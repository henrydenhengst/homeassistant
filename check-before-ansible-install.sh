#!/bin/bash
# =====================================================
# HA EXTRA CHECKS & HARDENING SCRIPT
# =====================================================
# Auteur: Henry den Hengst
# Doel: Alle hardware checks, extra tools, firewall, SSH hardening
#       en post-install status checks uitvoeren voor HA stack
# =====================================================

set -e
set -o pipefail

STACK_DIR="$HOME/home-assistant"
BACKUP_DIR="$STACK_DIR/backups"
DOCKER_COMPOSE_FILE="$STACK_DIR/docker-compose.yml"
LOG_FILE="$STACK_DIR/ha-extra.log"

mkdir -p "$STACK_DIR" "$BACKUP_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "START HA EXTRA CHECKS & HARDENING $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# =====================================================
# Install extra systeemtools
# =====================================================
apt update && apt install -y \
  ufw fail2ban memtester lm-sensors auditd stress-ng curl jq

echo "✅ Extra systeemtools geïnstalleerd"

# =====================================================
# Hardware Checks
# =====================================================
echo "📌 Hardware checks gestart..."

# Disk health (SMART)
DISKS=$(lsblk -dno NAME | grep -vE "loop|boot|sr")
for d in $DISKS; do
  DEV="/dev/$d"
  if command -v smartctl &> /dev/null; then
    STATUS=$(smartctl -H "$DEV" 2>/dev/null | awk -F': ' '/overall-health/ {print $2}')
    STATUS=${STATUS:-UNKNOWN}
    echo "💾 $DEV SMART status: $STATUS"
    smartctl -A "$DEV" | grep -E "Reallocated_Sector_Ct|Current_Pending_Sector"
  fi
done

# RAM test (optioneel)
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
echo "🧠 RAM beschikbaar: ${TOTAL_RAM}MB"
read -p "Wil je een korte RAM-test uitvoeren met memtester? [y/N]: " DO_MEM
if [[ "$DO_MEM" =~ ^[Yy]$ ]]; then
    TEST_MB=$(( TOTAL_RAM / 4 ))
    (( TEST_MB > 8192 )) && TEST_MB=8192
    echo "⚡ RAM-test uitvoeren: ${TEST_MB}MB"
    memtester "${TEST_MB}M" 1
fi

# CPU stress
if command -v stress-ng &> /dev/null; then
    echo "⚡ CPU korte stress-test (15s)"
    stress-ng --cpu $(nproc) -t 15s --quiet || echo "❌ CPU test failed"
fi

# Undervoltage (Raspberry Pi)
if command -v vcgencmd &> /dev/null; then
    UNDERVOLT=$(vcgencmd get_throttled | grep -v "0x0" || true)
    if [[ -n "$UNDERVOLT" ]]; then
        echo "⚠️  Undervoltage gedetecteerd! Controleer voeding"
    else
        echo "✅ Voeding stabiel"
    fi
fi

# =====================================================
# Firewall + SSH Hardening
# =====================================================
echo "📌 Configuratie firewall (UFW) en SSH hardening..."

# UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp                  # SSH
ufw allow 8120:8140/tcp           # HA stack poorten
ufw --force enable
echo "✅ UFW geconfigureerd"

# SSH root login uit
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
systemctl restart ssh
echo "✅ Root login SSH uitgeschakeld"

# Fail2Ban
tee /etc/fail2ban/jail.d/ssh.local > /dev/null <<EOF
[sshd]
enabled = true
maxretry = 3
bantime = 3600
findtime = 600
EOF
systemctl restart fail2ban
systemctl enable fail2ban
echo "✅ Fail2Ban geconfigureerd"

# =====================================================
# Homepage icon download
# =====================================================
echo "📥 Download homepage icons..."
declare -A ICONS=(
    ["home-assistant.png"]="https://raw.githubusercontent.com/home-assistant/brands/main/home-assistant/home-assistant.png"
    ["portainer.png"]="https://raw.githubusercontent.com/portainer/portainer/main/app/images/icon.png"
    ["nodered.png"]="https://raw.githubusercontent.com/node-red/node-red.github.io/master/images/red.png"
)
mkdir -p "$STACK_DIR/homepage/config"
for ICON in "${!ICONS[@]}"; do
    curl -sSL "${ICONS[$ICON]}" -o "$STACK_DIR/homepage/config/$ICON" || echo "⚠️ Fout bij downloaden $ICON"
done

# =====================================================
# Post-install checks
# =====================================================
echo "📌 Controleer container status en bereikbaarheid HA..."
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Container status
RUNNING=$(docker ps --format "{{.Names}}")
for c in $(docker compose -f "$DOCKER_COMPOSE_FILE" config --services); do
    if grep -q "^$c$" <<< "$RUNNING"; then
        echo -e "${GREEN}✅ Container '$c' draait${NC}"
    else
        echo -e "${RED}❌ Container '$c' draait NIET${NC}"
    fi
done

# HA bereikbaarheid
HA_IP=$(hostname -I | awk '{print $1}')
if curl -s -m 5 http://$HA_IP:8123 > /dev/null; then
    echo -e "${GREEN}✅ Home Assistant bereikbaar op http://$HA_IP:8123${NC}"
else
    echo -e "${RED}❌ Home Assistant NIET bereikbaar${NC}"
fi

# Device checks
for DEV in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0; do
    if [ -e "$DEV" ]; then
        echo "✅ Device aanwezig: $DEV"
    else
        echo "⚠️  Device NIET gevonden: $DEV"
    fi
done

echo "===================================================="
echo "✅ HA extra checks & hardening voltooid"