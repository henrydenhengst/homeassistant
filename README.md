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
- [Additional services](#additional-services)
- [Aanbevolen Aanvullende GitHub Repositories](#aanbevolen-aanvullende-github-repositories)
- [Aanbevolen Home Assistant GitHub Repositories](#aanbevolen-home-assistant-github-repositories)
- [Services & Poorten Overzicht](#services--poorten-overzicht)
- [Installatie Flow (Functioneel)](#installatie-flow-functioneel)


## Overzicht
Deze homelab-stack biedt een complete plug-and-play omgeving voor smart home automatisering, monitoring en serverbeheer. Het draait op **Debian 13 Minimal** en gebruikt Docker containers voor maximale isolatie, stabiliteit en eenvoud.  

Alle Docker-installaties gebruiken de **officiële Docker repositories** voor Debian 13, zodat je altijd de nieuwste stabiele versie krijgt.

> **Technische documentatie:** Alle installatie- en configuratiestappen zijn gedetailleerd beschreven in [`install.sh`](./install.sh).


## 🔹 Home Assistant Apparatuur

Voor een volledig overzicht van alle apparaten die je kunt integreren met Home Assistant, zie [apparatuur.md](./apparatuur.md).

> Tip: Hier vind je zowel veelvoorkomende apparaten, vergeten apparaten en Bluetooth (BLE) apparaten met integratie tips.


---

## Functies

### Home Assistant
- Centrale smart home hub.
- Ondersteunt Zigbee, Z-Wave, BLE, RF, IR en P1 Smart Meters.
- Verzamelt data via MQTT en slaat deze op in **MariaDB** voor betere prestaties.
- Dashboard configuratie via YAML-bestanden.

### Beszel
- **Hub**: dashboard met real-time systeemstatus en container monitoring.
- **Agent**: verzamelt metrics van de host machine.
- Lichtgewicht alternatief voor Netdata.
- Eenvoudig te koppelen met Home Assistant en andere services.

### Homepage
- Centrale startpagina voor alle webbased apps in het homelab.
- Statische links en statuswidgets voor:
  - Home Assistant
  - Portainer
  - Beszel
  - Uptime-Kuma
  - IT-Tools
- Basis YAML-bestanden worden automatisch aangemaakt bij eerste opstart.

### Uptime-Kuma
- Monitoren van uptime van services en externe websites.
- Waarschuwingen en meldingen bij downtime.


### RedNode
- **Wat is het:** Een web-based flow editor en visual programming tool voor Home Automation en IoT, vergelijkbaar met Node-RED.  
- **Functie:** Stroomlijnen van automatiseringen, logica, triggers en device-interacties.  
- **Integratie:** Werkt samen met Home Assistant via MQTT, API’s en websockets.  
- **Voordelen:** Drag-and-drop flows, eenvoudige debugging en real-time data monitoring.


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
- Betere prestaties dan standaard SQLite.
- Data migratie eenvoudig via `configuration.yaml`.

### DuckDNS
- Dynamische DNS voor externe toegang.
- Integreert met Home Assistant en andere webbased apps.

---

## Hardware Detectie
- Automatische detectie van USB-devices:
  - Zigbee, Z-Wave, BLE, RF, IR, P1 Smart Meters
- Detectie van Bluetooth-adapters.
- Containers starten alleen als het device aanwezig is.
- Logging van aangesloten hardware en mogelijke fouten.

---

## Netwerk Hardening
- Firewall configuratie via **UFW**:
  - Open poorten voor Home Assistant, Portainer, Beszel, Uptime-Kuma en IT-Tools.
  - Poort 22 open voor SSH.
  - Alle andere inkomende verbindingen standaard geblokkeerd.
- Fail2Ban voor extra SSH-bescherming.
- Root login via SSH uitgeschakeld.

---

## Backup & Data Management
- Automatische dagelijkse backups naar `backups/` directory.
- Backup van configuratiebestanden en kritieke data voor alle containers.
- Restore instructies beschikbaar in documentatie.

## Opmerkingen
- Minimum systeemvereisten: 15 GB vrije schijfruimte, 4 GB RAM.
- Hardware zoals Zigbee, Z-Wave of BLE wordt automatisch gedetecteerd.
- Alle logs en foutmeldingen worden weggeschreven naar `$HOME/ha-install.log`.

## Additional services:
- **Portainer** → Docker container management  
- **Dozzle** → Real-time container logs  
- **IT-Tools** → Diagnostics & utilities  
- **DuckDNS** → External access / dynamic DNS


## Aanbevolen Aanvullende GitHub Repositories

Om je homelab-stack nog krachtiger en vollediger te maken, zijn hier enkele nuttige repositories:

- [Zigbee2MQTT](https://github.com/Koenkk/zigbee2mqtt) – Voor Zigbee integratie en device management.
- [Z-Wave JS](https://github.com/zwave-js/zwavejs2mqtt) – Z-Wave controller en MQTT bridge.
- [ESPHome](https://github.com/esphome/esphome) – Voor het programmeren en beheren van ESP32/ESP8266 devices.
- [Home Assistant Community Add-ons](https://github.com/home-assistant/addons) – Officiële en community add-ons.
- [Uptime-Kuma](https://github.com/louislam/uptime-kuma) – Self-hosted monitoring van uptime en alerts.
- [Portainer CE](https://github.com/portainer/portainer) – Webinterface voor Docker beheer.
- [Beszel](https://github.com/henrygd/beszel) – Lightweight real-time monitoring dashboard.
- [Homepage](https://github.com/gethomepage/homepage) – Startpagina/dashboard voor al je web-apps.
- [IT-Tools](https://github.com/corentinth/it-tools) – Diagnostics & monitoring tools voor servers en netwerk.

> Tip: deze repos zijn optioneel, maar kunnen je homelab stack aanzienlijk uitbreiden en makkelijker beheren.


## Aanbevolen Home Assistant GitHub Repositories

Deze repositories zijn handig voor uitbreidingen, add-ons en integraties binnen je Home Assistant homelab:

- [Home Assistant Core](https://github.com/home-assistant/core) – De officiële Home Assistant core.
- [Home Assistant OS](https://github.com/home-assistant/operating-system) – Full OS images voor Home Assistant.
- [Home Assistant Supervisor](https://github.com/home-assistant/supervisor) – Beheer van add-ons en system services.
- [Home Assistant Add-ons](https://github.com/home-assistant/addons) – Officiële add-ons zoals MariaDB, Mosquitto, InfluxDB.
- [Zigbee2MQTT](https://github.com/Koenkk/zigbee2mqtt) – Zigbee integratie via MQTT.
- [Z-Wave JS](https://github.com/zwave-js/zwavejs2mqtt) – Z-Wave integratie via MQTT.
- [ESPHome](https://github.com/esphome/esphome) – ESP32/ESP8266 automatisering en sensoren.
- [HACS (Home Assistant Community Store)](https://github.com/hacs/integration) – Community add-ons en custom components.
- [Home Assistant Frontend](https://github.com/home-assistant/frontend) – Het web-dashboard en interface.
- [Home Assistant Supervisor Add-ons](https://github.com/home-assistant/addons) – Extra add-ons maintained door de community.
- [Home Assistant Naming Convention](https://github.com/Trikos/Home-Assistant-Naming-Convention) - Aanbevolen richtlijnen voor consistente naamgeving van entities, automations en dashboards, onmisbaar bij grotere setups.


## Populaire Full Dashboard Projects voor Home Assistant

Hier is een overzicht van populaire Home Assistant dashboards die je direct kunt bekijken en gebruiken:

### 1. Dwains Lovelace Dashboard
- **GitHub:** [dwainscheeren/dwains-lovelace-dashboard](https://github.com/dwainscheeren/dwains-lovelace-dashboard)
- **Beschrijving:** Een auto-genererend Lovelace-dashboard voor Home Assistant. Het bouwt automatisch een UI op basis van je HA-configuratie (areas/entities). Responsief voor desktop, tablet en mobiel.
- **Kenmerken:**
  - Automatische pagina’s gebaseerd op je entiteiten
  - Modern en overzichtelijk design
  - Geschikt voor touchscreens en tablets

### 2. Madelena Hass Config Public
- **GitHub:** [Madelena/hass-config-public](https://github.com/Madelena/hass-config-public)
- **Beschrijving:** Een persoonlijke maar zeer populaire Home Assistant-config met geavanceerde dashboards en layouts.
- **Kenmerken:**
  - Minimalistische ambient displays
  - Gedetailleerd “command center” dashboard
  - Geoptimaliseerd voor overzicht en functionaliteit

### 3. Home Assistant Mobile First
- **GitHub:** [Clooos/Home-Assistant-Mobile-First](https://github.com/topics/home-assistant-dashboard)
- **Beschrijving:** Een minimalistisch dashboard dat ontworpen is met mobile-first principes.
- **Kenmerken:**
  - Snel en overzichtelijk op mobiele apparaten
  - Clean design
  - Geschikt voor gebruikers die voornamelijk mobiel bedienen

### 4. Adaptive Mushroom
- **GitHub:** [Mushroom Dashboard](https://github.com/rafaelcaricio/mushroom-dashboard)
- **Beschrijving:** Minimalistische, adaptieve dashboards gebaseerd op Mushroom Cards.
- **Kenmerken:**
  - Modern en visueel aantrekkelijk
  - Past zich automatisch aan verschillende schermformaten aan
  - Gebruikt Mushroom custom cards voor consistente styling

### 5. Home Dashboard
- **GitHub:** [salgrow/home-dashboard](https://github.com/topics/home-assistant-dashboard)
- **Beschrijving:** Een modulair dashboard gericht op e-paper en smart displays.
- **Kenmerken:**
  - Diverse datapanels en integratie-opties
  - Focus op overzichtelijkheid en maatwerk
  - Ideaal voor vaste displays in huis


> Tip: deze repositories zijn perfect voor wie zijn Home Assistant setup wil uitbreiden met integraties, add-ons en custom components.

## Services & Poorten Overzicht

| Poort   | Service                 | Beschrijving                                          |
|--------|------------------------|------------------------------------------------------|
| 8120   | Mosquitto (MQTT)       | MQTT broker voor device-communicatie                 |
| 8121   | Zigbee2MQTT            | Zigbee integratie via MQTT                            |
| 8122   | ESPHome                | ESP32/ESP8266 programmering en device beheer        |
| 8123   | Home Assistant         | Centrale smart home hub                               |
| 8124   | Portainer (HTTP)       | Docker management interface                           |
| 8125   | Portainer (HTTPS)      | Docker management interface                           |
| 8126   | Dozzle                 | Real-time container logs                              |
| 8127   | InfluxDB               | Metrics database                                      |
| 8128   | Grafana                | Dashboard visualisatie van metrics                    |
| 8129   | Z-Wave JS              | Z-Wave integratie via MQTT                             |
| 8130*  | BLE2MQTT               | BLE devices via MQTT                                  |
| 8131*  | MQTT-IR / Beszel Hub   | IR devices via MQTT / real-time monitoring dashboard |
| 8132*  | P1 Monitor / Uptime-Kuma | Slimme meter uitlezing / uptime monitoring         |
| 8133   | Homepage               | Startpagina/dashboard voor web-apps                  |
| 8134   | CrowdSec               | Security & threat monitoring                           |
| 8135   | IT-Tools               | Diagnostics & monitoring tools                        |
| 8136   | RedNode   | Flow editor voor automatiseringen, integratie met Home Assistant via MQTT/API |
| --     | Watchtower             | Automatische container updates                        |
| --     | Beszel Agent           | Metric agent van de host                               |
| --     | DuckDNS                | Dynamische DNS update service                          |

\* Poorten kunnen verschillen afhankelijk van device-configuratie.  

> Tip: Services met “--” hebben geen publieke poort; toegang is via andere dashboards of de host.


---

```

┌──────────────┐
                     │ Home         │
                     │ Assistant    │
                     └─────┬────────┘
                           │ 💬 MQTT
          ┌────────────────┴───────────────┐
          │                               │
  ┌───────▼────────┐              ┌────────▼────────┐
  │ Zigbee2MQTT    │              │ Z-Wave JS       │
  │ (Zigbee USB)   │              │ (Z-Wave USB)    │
  └────────────────┘              └────────────────┘
          │                               │
          └─────────────┬─────────────────┘
                        │ 💬 MQTT
                  ┌─────▼─────┐
                  │ Mosquitto │
                  └─────┬─────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
 ┌──────▼─────┐                    ┌────▼─────┐
 │ MariaDB     │ 📊                  │ InfluxDB │ 📊
 │ (HA DB)     │                    │ Metrics  │
 └──────┬─────┘                    └────┬─────┘
        │                                 │
        │ 🖥️ Dashboard / Data            │ 🖥️ Dashboard / Metrics
  ┌─────▼────────┐                   ┌────▼────────┐
  │ Grafana      │ 🖥️                  │ RedNode     │ ⚡
  │ Dashboard    │                   │ Flow Editor │
  └─────┬────────┘                   └────┬───────┘
        │ 🖥️ Dashboard / Automations      │ ⚡ Flows / MQTT / API
 ┌──────▼────────┐                   ┌────▼────────┐
 │ Beszel Hub    │ 🖥️                  │ Homepage    │ 🖥️
 │ + Agent       │                   │ Dashboard   │
 └─────┬─────────┘                   └────┬────────┘
       │ Stats / Monitoring 🖥️            │ Links / Status 🖥️
       │                                   │
 ┌─────▼────────┐                   ┌─────▼────────┐
 │ Uptime-Kuma  │ 🖥️                  │ IT-Tools     │ 🖥️
 │ Alerts       │                   │ Diagnostics  │
 └──────────────┘                   └──────────────┘



