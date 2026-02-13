#!/bin/bash
# ========================================================
# Raspberry Pi 3 Edge Device Setup
# BLE Gateway + Node-RED + Optional IR/RF
# + Statisch IP
# ========================================================

# =========================================================
# Raspberry Pi 3 Edge Device Setup - Logging enabled
# =========================================================

# Logbestand locatie
LOG_FILE="$HOME/raspi_ble_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

echo "===================================================="
echo "START INSTALLATIE $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# ----------------------------
# 0. Variabelen netwerk
# ----------------------------
STATIC_IP="192.168.178.3"
ROUTER_IP="192.168.178.1"
DNS_SERVERS="9.9.9.9 1.1.1.1 8.8.8.8"
INTERFACE="wlan0"  # Pas aan naar eth0 indien nodig

sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null <<EOL

network={
    ssid="JOUW_SSID"
    psk="JOUW_WACHTWOORD"
    key_mgmt=WPA-PSK
}
EOL
sudo wpa_cli -i wlan0 reconfigure

# MQTT broker IP en topic
MQTT_BROKER="192.168.178.2"  # Mini-pc Home Assistant
MQTT_TOPIC="ble_gateway/pi3"

# Directories
BLE_DIR="$HOME/ble_gateway"
BLE_SCRIPT="$BLE_DIR/ble_gateway.py"

echo "==> Starting setup for Raspberry Pi 3 edge device..."

# ----------------------------
# 1. Controle netwerkinterface
# ----------------------------
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "ERROR: Interface $INTERFACE bestaat niet. Controleer met 'ip link'."
    exit 1
fi

# ----------------------------
# 2. Configure static IP
# ----------------------------
echo "==> Configuring static IP for $INTERFACE: $STATIC_IP"
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# Verwijder eerdere statische IP config voor interface
sudo sed -i "/interface $INTERFACE/,/static domain_name_servers/d" /etc/dhcpcd.conf

# Voeg nieuwe configuratie toe
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOL

# Static IP configuration added by setup script
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$ROUTER_IP
static domain_name_servers=$DNS_SERVERS
EOL

echo "==> Static IP configured. Restarting dhcpcd..."
sudo systemctl restart dhcpcd
sleep 5


# ----------------------------
# 5b. Configure UFW firewall
# ----------------------------
echo "==> Configuring UFW firewall..."
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Open benodigde poorten
sudo ufw allow 22/tcp         # SSH
sudo ufw allow 2136/tcp       # Node-RED
sudo ufw allow 1883/tcp       # MQTT

sudo ufw --force enable
sudo ufw status verbose
echo "✅ Firewall configured."

# ----------------------------
# 3. Update system packages
# ----------------------------
echo "==> Updating system packages..."
sudo apt update && sudo apt upgrade -y

# ----------------------------
# 4. Install dependencies
# ----------------------------
echo "==> Installing dependencies..."
sudo apt install -y git curl wget python3-pip python3-venv mosquitto mosquitto-clients build-essential lirc

# ----------------------------
# 5. Enable Mosquitto MQTT broker
# ----------------------------
echo "==> Enabling Mosquitto MQTT broker..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# ----------------------------
# 6. Install Node-RED if not installed
# ----------------------------
if ! command -v node-red > /dev/null; then
    echo "==> Installing Node-RED..."
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
    sudo systemctl enable nodered.service
    sudo systemctl start nodered.service
else
    echo "==> Node-RED already installed."
fi

# ----------------------------
# 7. Install Python BLE tools
# ----------------------------
echo "==> Installing Python BLE tools..."
sudo pip3 install --upgrade paho-mqtt bluepy

# ----------------------------
# 8. Create BLE gateway script
# ----------------------------
echo "==> Creating BLE gateway script..."
mkdir -p "$BLE_DIR"

cat > "$BLE_SCRIPT" <<EOF
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
from bluepy import btle
import time
import json

MQTT_BROKER = "$MQTT_BROKER"
MQTT_TOPIC = "$MQTT_TOPIC"

def scan_ble():
    scanner = btle.Scanner()
    devices = scanner.scan(5.0)
    return devices

client = mqtt.Client()
client.connect(MQTT_BROKER, 1883, 60)
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
# 9. Create systemd service
# ----------------------------
echo "==> Creating systemd service for BLE gateway..."
sudo tee /etc/systemd/system/ble_gateway.service > /dev/null <<EOL
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
# 11. Post-install health checks
# ----------------------------
log "==> Running post-install health checks..."

ERRORS=0

check_service() {
    if systemctl is-active --quiet "$1"; then
        log "✅ Service $1 running"
    else
        log "❌ Service $1 NOT running"
        ERRORS=$((ERRORS+1))
    fi
}

check_port() {
    if ss -tuln | grep -q ":$1 "; then
        log "✅ Port $1 open"
    else
        log "❌ Port $1 NOT open"
        ERRORS=$((ERRORS+1))
    fi
}

# ---- Network check ----
log "Checking network connectivity..."
if ping -c 2 "$ROUTER_IP" > /dev/null; then
    log "✅ Router reachable"
else
    log "❌ Router NOT reachable"
    ERRORS=$((ERRORS+1))
fi

if ping -c 2 8.8.8.8 > /dev/null; then
    log "✅ Internet reachable"
else
    log "❌ Internet NOT reachable"
    ERRORS=$((ERRORS+1))
fi

# ---- Service checks ----
check_service mosquitto
check_service nodered
check_service ble_gateway

# ---- Port checks ----
check_port 22
check_port 1883
check_port 2136

# ---- MQTT test ----
log "Testing MQTT publish..."
if mosquitto_pub -h "$MQTT_BROKER" -t test/pi -m "hello" ; then
    log "✅ MQTT publish OK"
else
    log "❌ MQTT publish FAILED"
    ERRORS=$((ERRORS+1))
fi

# ---- BLE hardware check ----
log "Checking BLE adapter..."
if hciconfig | grep -q "hci0"; then
    log "✅ BLE adapter detected"
else
    log "❌ BLE adapter NOT detected"
    ERRORS=$((ERRORS+1))
fi

# ---- Node-RED HTTP check ----
log "Checking Node-RED HTTP endpoint..."
if curl -s --max-time 5 "http://localhost:2136" > /dev/null; then
    log "✅ Node-RED responding"
else
    log "❌ Node-RED NOT responding"
    ERRORS=$((ERRORS+1))
fi

# ---- Summary ----
echo "--------------------------------------------------"
if [ "$ERRORS" -eq 0 ]; then
    log "🎉 ALL CHECKS PASSED"
else
    log "⚠️  $ERRORS CHECK(S) FAILED — Check log!"
fi
echo "--------------------------------------------------"

# ----------------------------
# 10. Setup complete
# ----------------------------
echo "==> Setup complete!"
echo "BLE gateway en Node-RED draaien nu op deze Pi 3."
echo "Pi heeft statisch IP: $STATIC_IP"
echo "Node-RED: http://$STATIC_IP:2136"
echo "Configureer Home Assistant op je mini-pc om MQTT-berichten van deze Pi te ontvangen."


