#!/bin/bash
# ========================================================
# Raspberry Pi 3 Edge Device Setup
# BLE Gateway + Node-RED + Optional IR/RF
# + Statisch IP
# ========================================================

set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# 0. Variabelen netwerk
# ----------------------------
STATIC_IP="192.168.178.3"
ROUTER_IP="192.168.178.1"
DNS_SERVERS="9.9.9.9 1.1.1.1 8.8.8.8"
INTERFACE="eth0"  # Pas aan naar wlan0 indien nodig

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
# 10. Setup complete
# ----------------------------
echo "==> Setup complete!"
echo "BLE gateway en Node-RED draaien nu op deze Pi 3."
echo "Pi heeft statisch IP: $STATIC_IP"
echo "Node-RED: http://$STATIC_IP:1880"
echo "Configureer Home Assistant op je mini-pc om MQTT-berichten van deze Pi te ontvangen."