
#!/bin/bash
# =====================================================
# FULL HOME ASSISTANT ANSIBLE STACK INSTALLER
# =====================================================
# Auteur: Henry den Hengst 
# Doel: Volledige Home Assistant homelab stack deployen
#       met alle benodigde containers en Ansible.
#
# Wat dit script doet:
# 1. Installeert basis dependencies en tools op Debian 13:
#    - Docker, docker-compose
#    - Ansible (met Python3 en pip)
#    - Git, curl, sudo
#
# 2. Maakt directories aan voor alle containers:
#    - homeassistant, MariaDB, Mosquitto, Zigbee2MQTT, Z-Wave JS,
#      BLE2MQTT, RFXtrx, MQTT-IR, P1Monitor, ESPHome, Node-RED,
#      Portainer, Watchtower, Dozzle, InfluxDB, Grafana, Beszel Hub+Agent,
#      Homepage, Uptime-Kuma, IT-Tools, CrowdSec, DuckDNS
#
# 3. Genereert een docker-compose Jinja2-template voor de volledige stack.
#
# 4. Genereert een Ansible playbook:
#    - Deployt de docker-compose template
#    - Start alle containers
#    - Controleert containerstatus
#
# 5. Voert het playbook direct uit.
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
 =====================================================
# HA INSTALLATIE SCRIPT MET VOORAFGEGAANDE ANSIBLE PRE-FLIGHT
# =====================================================

set -e
set -o pipefail

STACK_DIR="$HOME/home-assistant"
INVENTORY_FILE="$STACK_DIR/inventory.yml"
PRECHECK_PLAYBOOK="$STACK_DIR/ha-preflight.yml"
LOG_FILE="$STACK_DIR/ha-install.log"

mkdir -p "$STACK_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "START INSTALLATIE $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# -----------------------------------------------------
# Stap 1: Voer Ansible pre-flight checks uit
# -----------------------------------------------------
if [ ! -f "$PRECHECK_PLAYBOOK" ]; then
    echo "❌ Ansible pre-flight playbook niet gevonden: $PRECHECK_PLAYBOOK"
    echo "Maak eerst ha-preflight.yml aan in $STACK_DIR"
    exit 1
fi

echo "📌 Voer pre-flight checks uit met Ansible..."
ansible-playbook -i "$INVENTORY_FILE" "$PRECHECK_PLAYBOOK"
if [ $? -ne 0 ]; then
    echo "❌ Pre-flight checks zijn mislukt! Installatie wordt gestopt."
    exit 1
fi
echo "✅ Pre-flight checks geslaagd!"

# -----------------------------------------------------
# Stap 2: Hier start je de bestaande installatie
# -----------------------------------------------------
echo "🚀 Start Home Assistant stack installatie..."
# Je bestaande installatie-code hieronder, bv. Docker installatie, directories, compose, etc.


echo "===================================================="
echo "START FULL HA ANSIBLE STACK DEPLOYMENT $(date)"
echo "Logbestand: $LOG_FILE"
echo "===================================================="

# -----------------------------------------------------
# Variabelen
# -----------------------------------------------------
HA_STACK_DIR="$HOME/home-assistant"
INVENTORY_FILE="$HA_STACK_DIR/inventory.yml"
PLAYBOOK_FILE="$HA_STACK_DIR/deploy-ha.yml"
DOCKER_COMPOSE_TEMPLATE="$HA_STACK_DIR/docker-compose.yml.j2"

TZ="Europe/Amsterdam"
DUCKDNS_TOKEN="YOUR_TOKEN_HERE"  # Pas aan
DUCKDNS_SUBDOMAIN="myhome"       # Pas aan

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
    server1:
      ansible_host: 192.168.1.20
      ansible_user: debian
    server2:
      ansible_host: 192.168.1.21
      ansible_user: debian
  vars:
    ha_stack_dir: $HA_STACK_DIR
    tz: $TZ
    duckdns_token: $DUCKDNS_TOKEN
    duckdns_subdomain: $DUCKDNS_SUBDOMAIN
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
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: homeassistant
      MYSQL_USER: homeassistant
      MYSQL_PASSWORD: secretpassword
    volumes:
      - ./mariadb:/var/lib/mysql

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "8120:1883"
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
      - /dev/ttyUSB0:/dev/ttyUSB0
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
      - /dev/ttyUSB1:/dev/ttyUSB0
    environment:
      - TZ={{ tz }}

  ble2mqtt:
    image: thomaspfeiffer/ble2mqtt
    container_name: ble2mqtt
    restart: unless-stopped
    ports:
      - "8122:8080"
    devices:
      - /dev/ttyACM0:/dev/ttyACM0
    environment:
      - TZ={{ tz }}

  rfxtrx:
    image: mik3r/rfxtrx2mqtt
    container_name: rfxtrx
    restart: unless-stopped
    ports:
      - "8130:8080"
    devices:
      - /dev/ttyUSB2:/dev/ttyUSB2
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
      - portainer_data:/data

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
  portainer_data:
EOF

echo "✅ Docker Compose template aangemaakt met alle containers"

# -----------------------------------------------------
# Playbook genereren
# -----------------------------------------------------
cat > "$PLAYBOOK_FILE" <<EOF
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

echo "===================================================="
echo "✅ HA Ansible Stack deployment voltooid!"
echo "===================================================="

# -----------------------------------------------------
# Instructies en mogelijkheden
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
   - TZ: Timezone voor alle containers (standaard: $TZ)
   - DUCKDNS_TOKEN: token voor DuckDNS
   - DUCKDNS_SUBDOMAIN: subdomain voor DuckDNS
   - HA_STACK_DIR: pad waar de stack wordt aangemaakt

4️⃣ Opties:
   - Containers starten/updaten: docker compose -f \$HA_STACK_DIR/docker-compose.yml up -d
   - Stack status controleren: docker ps
   - Logs bekijken: tail -f $LOG_FILE

5️⃣ Logs:
   - Alle installatie- en deployment-logs worden opgeslagen in: $LOG_FILE

✅ Zo kun je de volledige Home Assistant stack lokaal of op meerdere Debian 13 servers beheren via Ansible.
====================================================

EOF