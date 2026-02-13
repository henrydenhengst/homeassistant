#!/bin/bash

################################
# PI SUPPORT INSTALL SCRIPT
################################

LOGFILE="/var/log/pi-install.log"

log() {
    echo "$(date) | $1" | tee -a $LOGFILE
}

log "==== PI INSTALL START ===="

################################
# UPDATE SYSTEM
################################

log "Updating system..."
apt update && apt upgrade -y

################################
# INSTALL BASE PACKAGES
################################

log "Installing base packages..."
apt install -y \
docker.io \
docker-compose \
ufw \
netcat-openbsd \
curl \
wget \
logrotate

systemctl enable docker
systemctl start docker

################################
# FIREWALL SETUP
################################

log "Configuring firewall..."

ufw allow ssh
ufw allow 2136/tcp

ufw --force enable

################################
# AUTO UPDATES
################################

log "Installing unattended upgrades..."

apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

################################
# HARDWARE WATCHDOG
################################

log "Installing hardware watchdog..."

apt install -y watchdog

sed -i 's/#watchdog-device/watchdog-device/' /etc/watchdog.conf || true

systemctl enable watchdog
systemctl start watchdog

################################
# CREATE SUPER WATCHDOG SCRIPT
################################

log "Installing super watchdog..."

cat << 'EOF' > /usr/local/bin/pi-super-watchdog.sh
#!/bin/bash

PORT=2136
MAX_FAILS=3
MAX_RAM_PERCENT=95

STATE_FILE="/tmp/pi-watchdog-fails"
LOG_FILE="/var/log/pi-super-watchdog.log"

fail_count=0

if [ -f "$STATE_FILE" ]; then
    fail_count=$(cat "$STATE_FILE")
fi

log() {
    echo "$(date) | $1" >> $LOG_FILE
}

################################
# NODE-RED CHECK
################################

if nc -z localhost $PORT; then
    log "Node-RED OK"
    echo 0 > $STATE_FILE
else
    fail_count=$((fail_count+1))
    log "Node-RED FAIL ($fail_count/$MAX_FAILS)"
    echo $fail_count > $STATE_FILE

    log "Restarting Node-RED container"
    docker restart nodered || true
    sleep 20

    if nc -z localhost $PORT; then
        log "Node-RED recovered"
        echo 0 > $STATE_FILE
    else
        if [ $fail_count -ge $MAX_FAILS ]; then
            log "Node-RED unrecoverable → REBOOT"
            reboot
        fi
    fi
fi

################################
# RAM CHECK
################################

RAM_USED=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100.0}')

if [ "$RAM_USED" -ge "$MAX_RAM_PERCENT" ]; then
    log "RAM CRITICAL (${RAM_USED}%) → REBOOT"
    reboot
else
    log "RAM OK (${RAM_USED}%)"
fi

################################
# SD HEALTH CHECK
################################

if mount | grep ' / ' | grep '(ro,' > /dev/null; then
    log "SD READ ONLY → REBOOT"
    reboot
fi

if dmesg | tail -n 50 | grep -i "mmc\|i/o error\|ext4 error" > /dev/null; then
    log "SD IO ERRORS → REBOOT"
    reboot
fi

log "System OK"
EOF

chmod +x /usr/local/bin/pi-super-watchdog.sh

################################
# SYSTEMD SERVICE
################################

log "Creating systemd watchdog service..."

cat << 'EOF' > /etc/systemd/system/pi-super-watchdog.service
[Unit]
Description=Pi Super Watchdog

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pi-super-watchdog.sh
EOF

################################
# SYSTEMD TIMER
################################

log "Creating watchdog timer..."

cat << 'EOF' > /etc/systemd/system/pi-super-watchdog.timer
[Unit]
Description=Run Pi Super Watchdog every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable pi-super-watchdog.timer
systemctl start pi-super-watchdog.timer

################################
# LOG ROTATION
################################

log "Configuring log rotation..."

cat << 'EOF' > /etc/logrotate.d/pi-super-watchdog
/var/log/pi-super-watchdog.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

################################
# FINAL CHECK
################################

log "Final system check..."

systemctl status docker --no-pager
systemctl status pi-super-watchdog.timer --no-pager

log "==== INSTALL COMPLETE ===="
