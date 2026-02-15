#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT ANSIBLE STACK INSTALLER (COMPLETE)
# =====================================================
# Auteur: Henry den Hengst (aangepast)
# Doel: Volledige Home Assistant homelab stack deployen
#       met Ansible en Docker Compose, volledig parametriseerbaar via .env
#       inclusief automatische USB detectie
#
# Mogelijkheden:
# - Lokaal draaien via 'local' inventory entry
# - Remote deployment op meerdere Debian 13 servers via SSH en Ansible
# - Variabelen aanpassen: TZ, DuckDNS-token, DuckDNS-subdomain, HA_STACK_DIR
# - Containers starten/updaten of logs bekijken
#
# Vereisten:
# - Debian 13 of compatibele distributie
# - Root-toegang op de host(s)
# - SSH-toegang bij remote deployment
#
# Logs:
# - Alles wordt weggeschreven naar $HOME/ha-ansible-full.log
#
# Gebruik:
#   sudo ./ha_ansible_full.sh
# =====================================================
set -e
set -o pipefail

# -----------------------------------------------------
# Laad configuratie uit .env
# -----------------------------------------------------
set -a  # auto-export alle variabelen
if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
    echo "✅ .env geladen"
else
    echo "❌ .env bestand niet gevonden in $HOME/.env"
    exit 1
fi
set +a
chmod 600 "$HOME/.env"

# -----------------------------------------------------
# Basis variabelen
# -----------------------------------------------------
STACK_DIR="$HOME/home-assistant"
LOG_FILE="$STACK_DIR/ha-ansible-full.log"
PRECHECK_PLAYBOOK="$STACK_DIR/ha-preflight.yml"

HA_STACK_DIR="$STACK_DIR"
INVENTORY_FILE="$HA_STACK_DIR/inventory.yml"
PLAYBOOK_FILE="$HA_STACK_DIR/deploy-ha.yml"
DOCKER_COMPOSE_TEMPLATE="$HA_STACK_DIR/docker-compose.yml.j2"

# USB variabelen
ZIGBEE_USB="${ZIGBEE_USB:-}"
ZWAVE_USB="${ZWAVE_USB:-}"
BLE_USB="${BLE_USB:-}"
RF_USB="${RF_USB:-}"
IR_USB="${IR_USB:-}"
P1_USB="${P1_USB:-}"
BT_USB="${BT_USB:-}"

# -------------------------------
# Log redirectie starten
# -------------------------------
mkdir -p "$STACK_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "START HA PRE-FLIGHT CHECK $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# -----------------------------------------------------
# Controleer pre-flight tools
# -----------------------------------------------------
TOOLS=(memtester stress-ng smartctl lm-sensors)
MISSING=()

for TOOL in "${TOOLS[@]}"; do
    if ! command -v "$TOOL" &> /dev/null; then
        MISSING+=("$TOOL")
    else
        echo "✅ Tool geïnstalleerd: $TOOL"
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "⚠️  Ontbrekende tools: ${MISSING[*]}"
    apt-get update -y
    apt-get install -y "${MISSING[@]}"
    echo "✅ Ontbrekende tools geïnstalleerd: ${MISSING[*]}"
else
    echo "✅ Alle benodigde tools zijn aanwezig"
fi

# -----------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------
if [ ! -f "$PRECHECK_PLAYBOOK" ]; then
    echo "❌ ha-preflight.yml ontbreekt in $STACK_DIR"
    exit 1
else
    echo "✅ ha-preflight.yml gevonden"
fi

if [[ -z "$DUCKDNS_TOKEN" ]]; then
    echo "❌ DUCKDNS_TOKEN niet ingesteld!"
    exit 1
fi
if [[ -z "$DUCKDNS_SUB" ]]; then
    echo "❌ DUCKDNS_SUB niet ingesteld!"
    exit 1
fi
echo "✅ DuckDNS variabelen ingesteld"

# -----------------------------------------------------
# Dynamische USB detectie
# -----------------------------------------------------
echo "📌 Start dynamische USB detectie..."
USB_MAP=(
    "ZIGBEE_USB"
    "ZWAVE_USB"
    "BLE_USB"
    "RF_USB"
    "IR_USB"
    "P1_USB"
    "BT_USB"
)

for USB_VAR in "${USB_MAP[@]}"; do
    DEV_PATH="${!USB_VAR}"
    if [ -z "$DEV_PATH" ] || [ ! -e "$DEV_PATH" ]; then
        FOUND=$(ls /dev/ttyUSB* 2>/dev/null | head -n1 || ls /dev/ttyACM* 2>/dev/null | head -n1 || ls /dev/hci* 2>/dev/null | head -n1)
        if [ -n "$FOUND" ]; then
            export $USB_VAR="$FOUND"
            echo "🔧 $USB_VAR automatisch ingesteld op $FOUND"
        else
            echo "⚠️  Geen geschikt device gevonden voor $USB_VAR"
            export $USB_VAR=""
        fi
    else
        echo "✅ Device aanwezig: $USB_VAR ($DEV_PATH)"
    fi
done

# Optionele hardware checks
echo "📌 Korte hardware checks (SMART, CPU, RAM)..."
if command -v smartctl &> /dev/null; then
    for d in $(lsblk -dno NAME | grep -vE "loop|boot|sr"); do
        echo "💾 $d SMART status:"
        smartctl -H "/dev/$d" || echo "⚠️ Kan SMART status niet lezen"
    done
fi

TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
echo "🧠 Beschikbaar RAM: ${TOTAL_RAM} MB"

if command -v stress-ng &> /dev/null; then
    echo "⚡ Korte CPU stress-test (5s)..."
    stress-ng --cpu 1 -t 5s --quiet || echo "⚠️ CPU stress-test mislukt"
fi

echo "===================================================="
echo "✅ HA PRE-FLIGHT CHECKS VOLTOOID"

# -----------------------------------------------------
# Installatie basis tools en Ansible
# -----------------------------------------------------
echo "📦 Installatie van Ansible en dependencies..."
apt update && apt install -y \
    python3 python3-pip python3-venv git curl sudo docker.io docker-compose

pip3 install --upgrade pip
pip3 install ansible jinja2
echo "✅ Ansible en Docker geïnstalleerd"

# -----------------------------------------------------
# Directories aanmaken
# -----------------------------------------------------
mkdir -p "$HA_STACK_DIR"
echo "✅ Directory $HA_STACK_DIR aangemaakt"

# -----------------------------------------------------
# Inventory genereren
# -----------------------------------------------------
cat > "$INVENTORY_FILE" <<EOF
all:
  hosts:
    local:
      ansible_connection: local
  vars:
    ha_stack_dir: "$HA_STACK_DIR"
    tz: "$HA_TZ"
    duckdns_token: "$DUCKDNS_TOKEN"
    duckdns_subdomain: "$DUCKDNS_SUB"
    mysql_root_password: "$MYSQL_ROOT_PASSWORD"
    mysql_user: "$MYSQL_USER"
    mysql_password: "$MYSQL_PASSWORD"
    mysql_database: "$MYSQL_DATABASE"
    mqtt_user: "$MQTT_USER"
    mqtt_password: "$MQTT_PASSWORD"
    zigbee_usb: "$ZIGBEE_USB"
    zwave_usb: "$ZWAVE_USB"
    ble_usb: "$BLE_USB"
    rf_usb: "$RF_USB"
    ir_usb: "$IR_USB"
    p1_usb: "$P1_USB"
    bt_usb: "$BT_USB"
    portainer_volume: "$PORTAINER_VOLUME"
EOF
echo "✅ Inventory aangemaakt op $INVENTORY_FILE"

# -----------------------------------------------------
# Docker Compose template genereren (Jinja2)
# -----------------------------------------------------
cat > "$DOCKER_COMPOSE_TEMPLATE" <<'EOF'
version: "3.9"

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    ports:
      - "8123:8123"
    volumes:
      - ./homeassistant:/config
    environment:
      - TZ={{ tz }}
    depends_on:
      - mariadb
      - mosquitto

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: {{ mysql_root_password }}
      MYSQL_DATABASE: {{ mysql_database }}
      MYSQL_USER: {{ mysql_user }}
      MYSQL_PASSWORD: {{ mysql_password }}
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "8120:1883"
    environment:
      - MQTT_USER={{ mqtt_user }}
      - MQTT_PASSWORD={{ mqtt_password }}
    volumes:
      - ./mosquitto:/mosquitto

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports:
      - "8121:8080"
    volumes:
      - ./zigbee2mqtt:/app/data
    devices:
      - "{{ zigbee_usb }}:{{ zigbee_usb }}"
    environment:
      - TZ={{ tz }}
    depends_on:
      - mosquitto

  zwavejs2mqtt:
    image: zwavejs/zwavejs2mqtt
    container_name: zwavejs2mqtt
    restart: unless-stopped
    ports:
      - "8129:8091"
    volumes:
      - ./zwavejs2mqtt:/usr/src/app/store
    devices:
      - "{{ zwave_usb }}:/dev/ttyUSB0"
    environment:
      - TZ={{ tz }}

  ble2mqtt:
    image: thomaspfeiffer/ble2mqtt
    container_name: ble2mqtt
    restart: unless-stopped
    ports:
      - "8122:8080"
    devices:
      - "{{ ble_usb }}:/dev/ttyACM0"
    environment:
      - TZ={{ tz }}

  rfxtrx:
    image: mik3r/rfxtrx2mqtt
    container_name: rfxtrx
    restart: unless-stopped
    ports:
      - "8130:8080"
    devices:
      - "{{ rf_usb }}:/dev/ttyUSB2"
    environment:
      - TZ={{ tz }}

  mqtt-ir:
    image: mqtt-ir
    container_name: mqtt-ir
    restart: unless-stopped
    ports:
      - "8136:8080"

  p1monitor:
    image: nielstron/p1monitor
    container_name: p1monitor
    restart: unless-stopped
    ports:
      - "8137:80"
    devices:
      - "{{ p1_usb }}:/dev/ttyUSB4"

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    restart: unless-stopped
    ports:
      - "8124:6052"
    volumes:
      - ./esphome:/config

  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports:
      - "2136:1880"
    volumes:
      - ./nodered_data:/data
    environment:
      - TZ={{ tz }}
    depends_on:
      - mosquitto

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    ports:
      - "8124:9000"
      - "8125:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - {{ portainer_volume }}:/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400

  dozzle:
    image: amir20/dozzle
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8126:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    restart: unless-stopped
    ports:
      - "8127:8086"
    volumes:
      - ./influxdb:/var/lib/influxdb2

  grafana:
    image: grafana/grafana-oss
    container_name: grafana
    restart: unless-stopped
    ports:
      - "8128:3000"
    volumes:
      - ./grafana:/var/lib/grafana

  beszel:
    image: henrygd/beszel:latest
    container_name: beszel
    restart: unless-stopped
    ports:
      - "8131:8090"
    volumes:
      - ./beszel_data:/data

  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports:
      - "8133:3000"
    volumes:
      - ./homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "8132:3001"
    volumes:
      - ./uptime-kuma:/app/data

  it-tools:
    image: corentinth/it-tools:latest
    container_name: it-tools
    restart: unless-stopped
    ports:
      - "8135:8080"
    volumes:
      - ./it-tools:/data

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    ports:
      - "8134:8080"
    volumes:
      - ./crowdsec:/etc/crowdsec

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ={{ tz }}
      - SUBDOMAINS={{ duckdns_subdomain }}
      - TOKEN={{ duckdns_token }}

volumes:
  {{ portainer_volume }}:
EOF

echo "✅ Docker Compose template aangemaakt met alle containers"

# -----------------------------------------------------
# Ansible Playbook genereren
# -----------------------------------------------------
cat > "$PLAYBOOK_FILE" <<'EOF'
---
- name: Deploy Full Home Assistant Stack via Docker Compose
  hosts: all
  become: true
  vars:
    ha_stack_dir: "{{ ha_stack_dir }}"
    docker_compose_file: "{{ ha_stack_dir }}/docker-compose.yml"

  tasks:
    - name: Installeer vereiste tools
      apt:
        name:
          - docker.io
          - docker-compose
          - git
          - python3-pip
        state: present
        update_cache: yes

    - name: Maak stack directory
      file:
        path: "{{ ha_stack_dir }}"
        state: directory
        mode: '0755'

    - name: Deploy docker-compose.yml
      template:
        src: docker-compose.yml.j2
        dest: "{{ docker_compose_file }}"
        mode: '0644'

    - name: Start alle containers
      shell: docker compose -f {{ docker_compose_file }} up -d
      args:
        chdir: "{{ ha_stack_dir }}"

    - name: Controleer status van containers
      shell: docker ps --format "table {{.Names}}\t{{.Status}}"
      register: container_status

    - name: Toon container status
      debug:
        var: container_status.stdout_lines
EOF

echo "✅ Ansible playbook aangemaakt"

# -----------------------------------------------------
# Playbook uitvoeren
# -----------------------------------------------------
echo "🚀 Playbook uitvoeren..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"

# -----------------------------------------------------
# Documentatie & instructies
# -----------------------------------------------------
cat <<EOF

====================================================
📌 Home Assistant Ansible Stack - Mogelijkheden
====================================================

1️⃣ Lokaal draaien:
   - Inventory bevat een 'local' host.
   - Het script installeert Docker en Ansible, genereert de stack en start containers lokaal.

2️⃣ Remote deployment:
   - Voeg servers toe in inventory.yml met 'ansible_host' en 'ansible_user'.
   - SSH-toegang (key of password) moet werken.
   - Run het script of ansible-playbook -i inventory.yml deploy-ha.yml
   - Alle taken: Docker install, directories maken, stack deployen, containers starten.

3️⃣ Variabelen aanpassen:
   - TZ: Timezone voor alle containers (standaard: $HA_TZ)
   - DUCKDNS_TOKEN: token voor DuckDNS
   - DUCKDNS_SUB: subdomain voor DuckDNS
   - HA_STACK_DIR: pad waar de stack wordt aangemaakt

4️⃣ Opties:
   - Containers starten/updaten: docker compose -f \$HA_STACK_DIR/docker-compose.yml up -d
   - Stack status controleren: docker ps
   - Logs bekijken: tail -f $LOG_FILE

5️⃣ USB Devices:
   - Dynamisch gedetecteerd als variabelen leeg zijn
   - Zigbee: $ZIGBEE_USB
   - Z-Wave: $ZWAVE_USB
   - BLE: $BLE_USB
   - RF: $RF_USB
   - IR: $IR_USB
   - P1: $P1_USB
   - BT: $BT_USB

6️⃣ Logs:
   - Alle installatie- en deployment-logs worden opgeslagen in: $LOG_FILE

✅ Zo kun je de volledige Home Assistant stack lokaal of op meerdere Debian 13 servers beheren via Ansible.
====================================================

EOF