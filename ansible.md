# 🏠 Home Assistant Homelab – Complete Cheatsheet

Alle commando’s die je nodig hebt om je Home Assistant stack lokaal of remote via Ansible te beheren. Inclusief pre-flight checks, Docker Compose beheer, backups en logs.

---

```bash
# RAM controleren
free -h

# CPU info
lscpu

# SMART status van schijven
sudo smartctl -H /dev/sda

# Korte CPU stress-test (5s)
stress-ng --cpu 1 -t 5s --quiet

# USB-devices detecteren
ls /dev/ttyUSB* /dev/ttyACM* /dev/hci*

# Pre-flight playbook uitvoeren
ansible-playbook -i inventory.yml ha-preflight.yml

# Full Home Assistant stack deployen
ansible-playbook -i inventory.yml deploy-ha.yml

# Alleen een bepaalde host targetten
ansible-playbook -i inventory.yml deploy-ha.yml --limit server1

# Ping alle hosts in inventory
ansible all -i inventory.yml -m ping

# Ansible facts ophalen van een host
ansible server1 -i inventory.yml -m setup

# Start alle containers (detached)
docker compose -f ~/home-assistant/docker-compose.yml up -d

# Stop alle containers
docker compose -f ~/home-assistant/docker-compose.yml down

# Backup config mappen
tar -czvf ha-backup-$(date +%F).tar.gz \
  ~/home-assistant/homeassistant \
  ~/home-assistant/mosquitto \
  ~/home-assistant/zigbee2mqtt \
  ~/home-assistant/zwavejs2mqtt \
  ~/home-assistant/ble2mqtt \
  ~/home-assistant/esphome \
  ~/home-assistant/nodered_data \
  ~/home-assistant/beszel_data \
  ~/home-assistant/homepage/config

# Restore backup
tar -xzvf ha-backup-YYYY-MM-DD.tar.gz -C ~/home-assistant/

# Variabelen laden in shell
export $(grep -v '^#' ~/.env | xargs)

# Controleer variabelen
echo $DUCKDNS_SUB
echo $DUCKDNS_TOKEN
echo $MYSQL_PASSWORD

# Pull laatste images en herstart containers
docker compose -f ~/home-assistant/docker-compose.yml pull
docker compose -f ~/home-assistant/docker-compose.yml up -d

# Watchtower doet automatisch dagelijkse updates
docker logs -f watchtower

# Home Assistant logs
docker logs -f homeassistant

# MQTT logs
docker logs -f mosquitto

# Zigbee2MQTT logs
docker logs -f zigbee2mqtt

# Node-RED logs
docker logs -f nodered
# Herstart 1 container
docker restart homeassistant

# Logs realtime volgen van 1 container
docker logs -f homeassistant

# Logs van alle containers bekijken
docker compose -f ~/home-assistant/docker-compose.yml logs -f

# Container status controleren
docker ps

# Controleer netwerk en volumes
docker network ls
docker volume ls

