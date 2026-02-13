#!/bin/bash
# ========================================================
# Raspberry Pi 3 Edge Device Setup
# BLE Gateway + Node-RED + Optional IR/RF
# + Statisch IP + Watchdog + Auto Updates + SD check
# + Periodic health check + Logrotate
# ========================================================

set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Logging
# ----------------------------
LOG_FILE="$HOME/raspi_ble_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

echo "===================================================="
echo "START INSTALLATIE $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# ----------------------------
# 0. Netwerkvariabelen
# ----------------------------
STATIC_IP="192.168.178.3"
ROUTER_IP="192.168.178.1"
DNS_SERVERS="9.9.9.9 1.1.1.1 8.8.8.8"
INTERFACE="wlan0"  # of eth0

SSID="JOUW_SSID"
WPA_PASSWORD="JOUW_WACHTWOORD"

# MQTT
MQTT_BROKER="192.168.178.2"
MQTT_PORT=8120
MQTT_TOPIC="ble_gateway/pi3"

# BLE gateway
BLE_DIR="$HOME/ble_gateway"
BLE_SCRIPT="$BLE_DIR/ble_gateway.py"

# Node-RED poort
NODERED_PORT=2136

# ----------------------------
# 1. Configure WiFi
# ----------------------------
log "==> Configuring WiFi..."
sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null <<EOL

network={
    ssid="$SSID"
    psk="$WPA_PASSWORD"
    key_mgmt=WPA-PSK
}
EOL
sudo wpa_cli -i "$INTERFACE" reconfigure

# ----------------------------
# 2. Configure static IP
# ----------------------------
log "==> Configuring static IP..."
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
sudo sed -i "/interface $INTERFACE/,/static domain_name_servers/d" /etc/dhcpcd.conf

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOL

# Static IP configuration added by setup script
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$ROUTER_IP
static domain_name_servers=$DNS_SERVERS
EOL

sudo systemctl restart dhcpcd
sleep 5

# ----------------------------
# 3. Install updates & dependencies
# ----------------------------
log "==> Updating system packages..."
sudo apt update && sudo apt upgrade -y

log "==> Installing dependencies..."
sudo apt install -y git curl wget python3-pip python3-venv mosquitto mosquitto-clients build-essential lirc ufw htop smartmontools unattended-upgrades watchdog

# ----------------------------
# 4. Configure UFW firewall
# ----------------------------
log "==> Configuring UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow "$NODERED_PORT"/tcp
sudo ufw allow "$MQTT_PORT"/tcp
sudo ufw --force enable
sudo ufw status verbose

# ----------------------------
# 5. Enable Mosquitto
# ----------------------------
log "==> Enabling Mosquitto MQTT broker..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# ----------------------------
# 6. Install Node-RED if missing
# ----------------------------
if ! command -v node-red >/dev/null; then
    log "==> Installing Node-RED..."
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
fi
sudo systemctl enable nodered.service
sudo systemctl start nodered.service

# ----------------------------
# 7. Install Python BLE tools
# ----------------------------
log "==> Installing Python BLE tools..."
sudo pip3 install --upgrade paho-mqtt bluepy

# ----------------------------
# 8. Create BLE gateway script
# ----------------------------
log "==> Creating BLE gateway script..."
mkdir -p "$BLE_DIR"
cat > "$BLE_SCRIPT" <<EOF
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
from bluepy import btle
import time, json

MQTT_BROKER = "$MQTT_BROKER"
MQTT_PORT = $MQTT_PORT
MQTT_TOPIC = "$MQTT_TOPIC"

def scan_ble():
    scanner = btle.Scanner()
    return scanner.scan(5.0)

client = mqtt.Client()
client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_start()

while True:
    try:
        devices = scan_ble()
        for dev in devices:
            msg = {"addr": dev.addr, "rssi": dev.rssi}
            client.publish(MQTT_TOPIC, json.dumps(msg))
    except Exception as e:
        print(f"BLE scan error: {e}")
    time.sleep(10)
EOF
chmod +x "$BLE_SCRIPT"

# ----------------------------
# 9. Create BLE systemd service
# ----------------------------
log "==> Creating BLE gateway service..."
sudo tee /etc/systemd/system/ble_gateway.service >/dev/null <<EOL
[Unit]
Description=BLE Gateway to MQTT
After=network.target

[Service]
ExecStart=$BLE_SCRIPT
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ble_gateway
User=$USER

[Install]
WantedBy=multi-user.target
EOL
sudo systemctl daemon-reload
sudo systemctl enable ble_gateway
sudo systemctl start ble_gateway

# ----------------------------
# 10. Watchdog & Auto Updates
# ----------------------------
log "==> Setting up watchdog & auto updates..."
sudo systemctl enable watchdog
sudo systemctl start watchdog
sudo dpkg-reconfigure --priority=low unattended-upgrades

# ----------------------------
# 11. SD health check service
# ----------------------------
log "==> Creating SD card health check service..."
SD_CHECK_SCRIPT="/usr/local/bin/sd_health_check.sh"
sudo tee "$SD_CHECK_SCRIPT" >/dev/null <<'EOF'
#!/bin/bash
LOG="/var/log/sd_health.log"
echo "[$(date)] Running SD card health check" >> $LOG
if sudo smartctl -a /dev/mmcblk0 | grep -q "Errors"; then
    echo "[$(date)] SD card reports errors, restarting Node-RED then rebooting..." >> $LOG
    systemctl restart nodered
    sleep 5
    reboot
fi
EOF
sudo chmod +x "$SD_CHECK_SCRIPT"

sudo tee /etc/systemd/system/sd_health.service >/dev/null <<EOL
[Unit]
Description=SD Card Health Check
After=network.target

[Service]
ExecStart=$SD_CHECK_SCRIPT
Type=oneshot

[Install]
WantedBy=multi-user.target
EOL
sudo systemctl daemon-reload
sudo systemctl enable sd_health.service

# ----------------------------
# 12. Periodic service health check (Node-RED + BLE)
# ----------------------------
log "==> Creating periodic service health check..."
SERVICE_CHECK_SCRIPT="/usr/local/bin/service_health_check.sh"
sudo tee "$SERVICE_CHECK_SCRIPT" >/dev/null <<'EOF'
#!/bin/bash
LOG="/var/log/service_health.log"
SERVICES=("nodered" "ble_gateway")

for S in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$S"; then
        echo "[$(date)] $S not running, restarting..." >> $LOG
        systemctl restart "$S"
    else
        echo "[$(date)] $S running OK" >> $LOG
    fi
done
EOF
sudo chmod +x "$SERVICE_CHECK_SCRIPT"

# Cron job elke 5 minuten
sudo tee /etc/cron.d/service_health >/dev/null <<EOF
*/5 * * * * root $SERVICE_CHECK_SCRIPT
EOF

# ----------------------------
# 13. Logrotate
# ----------------------------
log "==> Setting up logrotate..."
LOGROTATE_CONF="/etc/logrotate.d/raspi_ble_logs"
sudo tee "$LOGROTATE_CONF" >/dev/null <<EOF
$HOME/*.log /var/log/service_health.log /var/log/sd_health.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF

# ----------------------------
# 14. Post-install health checks
# ----------------------------
log "==> Running post-install health checks..."
ERRORS=0
check_service() { systemctl is-active --quiet "$1" && log "✅ $1 running" || { log "❌ $1 NOT running"; ERRORS=$((ERRORS+1)); } }
check_port() { ss -tuln | grep -q ":$1 " && log "✅ Port $1 open" || { log "❌ Port $1 NOT open"; ERRORS=$((ERRORS+1)); } }

check_service mosquitto
check_service nodered
check_service ble_gateway

check_port 22
check_port "$MQTT_PORT"
check_port "$NODERED_PORT"

ping -c2 "$ROUTER_IP" >/dev/null && log "✅ Router reachable" || { log "❌ Router NOT reachable"; ERRORS=$((ERRORS+1)); }
ping -c2 8.8.8.8 >/dev/null && log "✅ Internet reachable" || { log "❌ Internet NOT reachable"; ERRORS=$((ERRORS+1)); }

hciconfig | grep -q "hci0" && log "✅ BLE adapter detected" || { log "❌ BLE adapter NOT detected"; ERRORS=$((ERRORS+1)); }

curl -s --max-time 5 "http://localhost:$NODERED_PORT" >/dev/null && log "✅ Node-RED responding" || { log "❌ Node-RED NOT responding"; ERRORS=$((ERRORS+1)); }

mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t test/pi -m "hello" && log "✅ MQTT publish OK" || { log "❌ MQTT publish FAILED"; ERRORS=$((ERRORS+1)); }

if [ "$ERRORS" -eq 0 ]; then
    log "🎉 ALL CHECKS PASSED"
else
    log "⚠️ $ERRORS CHECK(S) FAILED — see $LOG_FILE"
fi

# ----------------------------
# 15. Setup complete
# ----------------------------
echo "==> Setup complete!"
echo "BLE gateway en Node-RED draaien nu op deze Pi 3."
echo "Pi statisch IP: $STATIC_IP"
echo "Node-RED: http://$STATIC_IP:$NODERED_PORT"
echo "MQTT naar mini-pc poort: $MQTT_PORT"
echo "Home Assistant kan nu MQTT-berichten ontvangen van deze Pi."