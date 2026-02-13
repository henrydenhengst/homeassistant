#!/bin/bash
# ========================================================
# Raspberry Pi 3 Edge Device Setup
# BLE Gateway + Node-RED + Optional IR/RF
# + Statisch IP
# ========================================================

set -e

# ----------------------------
# 1. Configure static IP
# ----------------------------
# Pas deze waarden aan voor je netwerk
STATIC_IP="192.168.1.50"
ROUTER_IP="192.168.1.1"
DNS_SERVER="8.8.8.8"
INTERFACE="eth0"  # kies eth0 of wlan0

echo "==> Configuring static IP for $INTERFACE: $STATIC_IP"

# Maak backup van dhcpcd.conf
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# Voeg statische IP configuratie toe
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOL

# Static IP configuration added by setup script
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$ROUTER_IP
static domain_name_servers=$DNS_SERVER
EOL

# Herstart netwerk om IP toe te passen
sudo systemctl restart dhcpcd
sleep 5
echo "==> Static IP configured: $STATIC_IP"

# ----------------------------
# 2. Update system packages
# ----------------------------
echo "==> Updating system"
sudo apt update && sudo apt upgrade -y

# ----------------------------
# 3. Install dependencies
# ----------------------------
echo "==> Installing dependencies"
sudo apt install -y git curl wget python3-pip python3-venv mosquitto mosquitto-clients build-essential lirc

# ----------------------------
# 4. Enable and start Mosquitto
# ----------------------------
echo "==> Enabling Mosquitto MQTT broker"
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# ----------------------------
# 5. Install Node-RED
# ----------------------------
echo "==> Installing Node-RED"
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
sudo systemctl enable nodered.service
sudo systemctl start nodered.service

# ----------------------------
# 6. Install Python BLE tools
# ----------------------------
echo "==> Installing Python BLE tools"
sudo pip3 install paho-mqtt bluepy

# ----------------------------
# 7. Create BLE gateway script
# ----------------------------
echo "==> Creating BLE gateway script"
mkdir -p ~/ble_gateway
cat > ~/ble_gateway/ble_gateway.py <<'EOF'
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
from bluepy import btle
import time
import json

MQTT_BROKER = "192.168.1.100"  # IP van mini-pc HA MQTT broker
MQTT_TOPIC = "ble_gateway"

def scan_ble():
    scanner = btle.Scanner()
    devices = scanner.scan(5.0)
    return devices

client = mqtt.Client()
client.connect(MQTT_BROKER, 1883, 60)
client.loop_start()

while True:
    devices = scan_ble()
    for dev in devices:
        msg = {"addr": dev.addr, "rssi": dev.rssi}
        client.publish(MQTT_TOPIC, json.dumps(msg))
    time.sleep(10)
EOF

chmod +x ~/ble_gateway/ble_gateway.py

# ----------------------------
# 8. Create systemd service for BLE gateway
# ----------------------------
echo "==> Creating systemd service for BLE gateway"
sudo tee /etc/systemd/system/ble_gateway.service > /dev/null <<EOL
[Unit]
Description=BLE Gateway to MQTT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/ble_gateway/ble_gateway.py
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable ble_gateway
sudo systemctl start ble_gateway

echo "==> Setup complete!"
echo "BLE gateway en Node-RED draaien nu op deze Pi 3."
echo "Pi heeft statisch IP: $STATIC_IP"
echo "Configureer Home Assistant op je mini-pc om MQTT-berichten van deze Pi te ontvangen."