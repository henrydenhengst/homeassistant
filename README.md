# 🏠 Homelab Dashboard & Automation Stack

## Inhoudsopgave
- [Overzicht](#overzicht)
- [Functies](#functies)
  - [Home Assistant](#home-assistant)
  - [Beszel](#beszel)
  - [Homepage](#homepage)
  - [Uptime-Kuma](#uptime-kuma)
  - [RedNode](#rednode)
  - [Grafana & InfluxDB](#grafana--influxdb)
  - [Portainer](#portainer)
  - [Dozzle](#dozzle)
  - [IT-Tools](#it-tools)
  - [Mosquitto (MQTT)](#mosquitto-mqtt)
  - [MariaDB](#mariadb)
  - [DuckDNS](#duckdns)
- [Hardware Detectie](#hardware-detectie)
- [Netwerk Hardening](#netwerk-hardening)
- [Backup & Data Management](#backup--data-management)
- [Opmerkingen](#opmerkingen)
- [Additional Services](#additional-services)
- [Aanbevolen GitHub Repositories](#aanbevolen-github-repositories)
- [Home Assistant Repositories](#home-assistant-repositories)
- [Services & Poorten Overzicht](#services--poorten-overzicht)
- [Homelab Flow Diagram](#homelab-flow-diagram)

---

## Overzicht
Deze homelab-stack biedt een complete plug-and-play omgeving voor **smart home automatisering, monitoring en serverbeheer**. Het draait op **Debian 13 Minimal** en gebruikt Docker-containers voor maximale isolatie, stabiliteit en eenvoud.  

Alle Docker-installaties gebruiken de **officiële Docker repositories** voor Debian 13, zodat je altijd de nieuwste stabiele versie krijgt.

> **Technische documentatie:** Zie [`install.sh`](./install.sh) voor volledige installatie- en configuratiestappen.

---

## 🔹 Home Assistant Apparatuur
Voor een volledig overzicht van apparaten die je kunt integreren met Home Assistant, zie [apparatuur.md](./apparatuur.md).  

> Tip: Hier vind je integratie-tips voor Zigbee, Z-Wave, BLE, RF, IR en P1 Smart Meters.

---

## Functies

### Home Assistant
- Centrale smart home hub.
- Ondersteunt Zigbee, Z-Wave, BLE, RF, IR en P1 Smart Meters.
- Verzamelt data via MQTT en slaat deze op in **MariaDB** voor betere prestaties.
- Dashboard configuratie via YAML-bestanden.

### Beszel
- **Hub**: real-time systeemstatus en container monitoring.
- **Agent**: verzamelt metrics van de host machine.
- Lichtgewicht alternatief voor Netdata.
- Integreerbaar met Home Assistant en andere services.

### Homepage
- Centrale startpagina voor alle web-apps.
- Links en statuswidgets voor Home Assistant, Portainer, Beszel, Uptime-Kuma en IT-Tools.
- Basis YAML-bestanden worden automatisch aangemaakt bij eerste opstart.

### Uptime-Kuma
- Monitoren van uptime van services en externe websites.
- Waarschuwingen en meldingen bij downtime.

### RedNode
- Web-based flow editor en visual programming tool (vergelijkbaar met Node-RED).  
- Stroomlijnen van automatiseringen, logica, triggers en device-interacties.  
- Werkt samen met Home Assistant via MQTT, API’s en websockets.

### Grafana & InfluxDB
- Historische metrics en visualisatie van systeem- en containerstatistieken.
- Grafana dashboards voor CPU, RAM, Disk, Docker containers en meer.

### Portainer
- Docker management interface.
- Containerbeheer, volume-inspectie en netwerkbeheer.

### Dozzle
- Real-time logging van Docker containers.
- Handig voor debugging en monitoring.

### IT-Tools
- Webinterface met diagnostische tools voor netwerk en systeem.
- Toont hardware-informatie, logs en netwerkstatus.

### Mosquitto (MQTT)
- Berichtenbus voor smart home devices en automatisering.
- Communicatie tussen Home Assistant, Zigbee2MQTT, Z-Wave JS, BLE2MQTT en andere IoT-devices.

### MariaDB
- MySQL-database voor Home Assistant.
- Sneller dan standaard SQLite.
- Eenvoudige data migratie via `configuration.yaml`.

### DuckDNS
- Dynamische DNS voor externe toegang.
- Integreert met Home Assistant en andere web-apps.

---

## Hardware Detectie
- Detectie van USB-devices: Zigbee, Z-Wave, BLE, RF, IR, P1 Smart Meters.
- Detectie van Bluetooth-adapters.
- Containers starten alleen als device aanwezig is.
- Logging van aangesloten hardware en fouten.

---

## Netwerk Hardening
- Firewall via **UFW**:
  - Open poorten voor Home Assistant, Portainer, Beszel, Uptime-Kuma en IT-Tools.
  - Poort 22 voor SSH.
  - Alle andere inkomende verbindingen standaard geblokkeerd.
- Fail2Ban voor SSH-bescherming.
- Root login via SSH uitgeschakeld.

---

## Backup & Data Management
- Dagelijkse automatische backups naar `backups/`.
- Backup van configuratie en kritieke containerdata.
- Restore instructies beschikbaar in documentatie.

---

## Opmerkingen
- Minimum systeemvereisten: 15 GB vrije schijfruimte, 4 GB RAM.
- Alle logs en fouten worden opgeslagen in `$HOME/ha-install.log`.

---

## Additional Services
- **Portainer** → Docker container management  
- **Dozzle** → Real-time container logs  
- **IT-Tools** → Diagnostics & utilities  
- **DuckDNS** → External access / dynamic DNS  

---

## Aanbevolen GitHub Repositories
- [Zigbee2MQTT](https://github.com/Koenkk/zigbee2mqtt) – Zigbee integratie.  
- [Z-Wave JS](https://github.com/zwave-js/zwavejs2mqtt) – Z-Wave controller via MQTT.  
- [ESPHome](https://github.com/esphome/esphome) – ESP32/ESP8266 devices.  
- [Home Assistant Add-ons](https://github.com/home-assistant/addons) – Officiële add-ons.  
- [Uptime-Kuma](https://github.com/louislam/uptime-kuma) – Self-hosted monitoring.  
- [Portainer](https://github.com/portainer/portainer) – Docker beheer.  
- [Beszel](https://github.com/henrygd/beszel) – Real-time monitoring.  
- [Homepage](https://github.com/gethomepage/homepage) – Startpagina/dashboard.  
- [IT-Tools](https://github.com/corentinth/it-tools) – Diagnostics tools.  

---

## Home Assistant Repositories
- [Home Assistant Core](https://github.com/home-assistant/core)  
- [Home Assistant OS](https://github.com/home-assistant/operating-system)  
- [Home Assistant Supervisor](https://github.com/home-assistant/supervisor)  
- [ESPHome](https://github.com/esphome/esphome)  
- [Zigbee2MQTT](https://github.com/Koenkk/zigbee2mqtt)  
- [Z-Wave JS](https://github.com/zwave-js/zwavejs2mqtt)  
- [HACS](https://github.com/hacs/integration) – Community add-ons  
- [Home Assistant Frontend](https://github.com/home-assistant/frontend)  
- [Naming Convention](https://github.com/Trikos/Home-Assistant-Naming-Convention)  

---

## Services & Poorten Overzicht

| Poort   | Service                 | Beschrijving                                          |
|--------|------------------------|------------------------------------------------------|
| 8120   | Mosquitto (MQTT)       | MQTT broker voor device-communicatie                 |
| 8121   | Zigbee2MQTT            | Zigbee integratie via MQTT                            |
| 8122   | ESPHome                | ESP32/ESP8266 programmering                           |
| 8123   | Home Assistant         | Centrale smart home hub                               |
| 8124   | Portainer (HTTP)       | Docker management interface                           |
| 8125   | Portainer (HTTPS)      | Docker management interface                           |
| 8126   | Dozzle                 | Real-time container logs                              |
| 8127   | InfluxDB               | Metrics database                                      |
| 8128   | Grafana                | Dashboard visualisatie van metrics                    |
| 8129   | Z-Wave JS              | Z-Wave integratie via MQTT                             |
| 8130*  | BLE2MQTT               | BLE devices via MQTT                                  |
| 8131*  | MQTT-IR / Beszel Hub   | IR devices via MQTT / monitoring dashboard          |
| 8132*  | P1 Monitor / Uptime-Kuma | Slimme meter uitlezing / uptime monitoring         |
| 8133   | Homepage               | Startpagina/dashboard voor web-apps                  |
| 8134   | CrowdSec               | Security & threat monitoring                          |
| 8135   | IT-Tools               | Diagnostics & monitoring tools                        |
| 8136   | RedNode                | Flow editor voor automatiseringen, MQTT/API          |
| --     | Watchtower             | Automatische container updates                        |
| --     | Beszel Agent           | Metric agent van de host                               |
| --     | DuckDNS                | Dynamische DNS update service                          |

\* Poorten kunnen verschillen afhankelijk van device-configuratie.

---

## Homelab Flow Diagram

```mermaid
flowchart TD
    %% Home Automation Core
    HA[🏠 Home Assistant]
    Z2M[🟡 Zigbee2MQTT<br>(Zigbee USB)]
    ZWave[🔵 Z-Wave JS<br>(Z-Wave USB)]
    BLE2MQTT[🔹 BLE2MQTT<br>(BLE devices)]
    MQTTIR[⚡ MQTT-IR / Beszel Hub<br>(IR devices)]
    P1[📊 Smart Meter / Uptime-Kuma]
    Mosq[💬 Mosquitto<br>MQTT Broker]

    %% Databases
    MariaDB[💾 MariaDB<br>HA DB]
    Influx[📈 InfluxDB<br>Metrics DB]

    %% Dashboards / Monitoring
    Grafana[📊 Grafana<br>Dashboard]
    RedNode[🔧 RedNode<br>Flow Editor]
    Beszel[📡 Beszel Hub + Agent]
    Homepage[🌐 Homepage Dashboard]
    Uptime[⏱️ Uptime-Kuma<br>Alerts]
    IT[🖥️ IT-Tools<br>Diagnostics]

    %% Additional Services
    Portainer[📦 Portainer<br>Docker Management]
    Dozzle[📝 Dozzle<br>Container Logs]
    DuckDNS[🌍 DuckDNS<br>Dynamic DNS]
    CrowdSec[🛡️ CrowdSec<br>Security Monitoring]
    Watchtower[🔄 Watchtower<br>Auto Container Updates]

    %% Connections: Devices -> MQTT
    Z2M -->|MQTT| Mosq
    ZWave -->|MQTT| Mosq
    BLE2MQTT -->|MQTT| Mosq
    MQTTIR -->|MQTT| Mosq
    P1 -->|MQTT| Mosq
    HA -->|MQTT| Mosq

    %% Databases
    Mosq --> MariaDB
    Mosq --> Influx

    %% Dashboards / Automation
    MariaDB --> Grafana
    Influx --> Grafana
    Grafana --> Beszel
    Grafana --> RedNode
    RedNode --> Homepage
    Beszel --> Homepage
    Beszel --> Uptime
    Homepage --> IT

    %% Additional Services links
    Portainer --> Dozzle
    Watchtower --> Portainer
    DuckDNS --> HA
    CrowdSec --> HA