
# Home Assistant Homelab Installer

Een run-once Bash-script dat een volledige Home Assistant homelab stack installeert en configureert op Debian 13 minimal.

## Functionaliteiten

- Installeert en configureert de volledige Home Assistant stack:
  - Home Assistant via Docker
  - MariaDB database voor Home Assistant
  - Mosquitto MQTT broker
  - Zigbee2MQTT, Z-Wave JS, BLE2MQTT, RFXtrx, MQTT-IR, P1Monitor (indien aanwezige hardware)
  - IT-Tools webinterface
  - Docker en Docker Compose
  - WireGuard VPN met server- en clientconfiguratie
  - DuckDNS integratie
  - CrowdSec monitoring
  - UFW firewall en SSH hardening
  - Automatische dagelijkse backups
- Detecteert automatisch aangesloten USB-devices en voegt de bijbehorende containers toe.
- Houdt een installatie-log bij in het homelab-home directory.

## Systeemvereisten

- Debian 13 minimal
- Minimaal 14 GB vrije schijfruimte
- Minimaal 3 GB RAM
- Root-toegang
- Internetverbinding

## Installatieprocedure

1. Maak een `.env` bestand aan met alle vereiste variabelen, zoals tijdzone, database credentials en DuckDNS subdomein.
2. Run het script één keer als root.
3. Optioneel kunnen statisch IP en gateway worden meegegeven als parameters.

## Post-install overzicht

- Home Assistant is bereikbaar via het lokale IP en poort 8123.
- IT-Tools webinterface is beschikbaar op poort 8135.
- CrowdSec dashboard is beschikbaar op poort 8080.
- WireGuard clientconfiguratie wordt opgeslagen in de homelab-directory.
- Alle backups worden automatisch opgeslagen in de homelab-backup directory.
- Installatie- en foutmeldingen worden gelogd in het logbestand.

## Netwerk en beveiliging

- WireGuard VPN draait op poort 51820/udp.
- UFW staat standaard incoming verkeer uit en outgoing verkeer toe.
- SSH root login is uitgeschakeld, toegang alleen voor geconfigureerde gebruikers.
- CrowdSec en Fail2Ban beschermen tegen brute-force en andere aanvallen.

## Backups en logging

- Dagelijkse automatische backup van de volledige stack.
- Backups bevatten geen plaintext wachtwoorden.
- Installatie- en runtime-logs zijn beschikbaar in de homelab-directory.

## Aanpassen en uitbreiden

- `.env` bestand bevat alle gevoelige variabelen en configuratieopties.
- Extra USB-devices worden automatisch herkend en geconfigureerd.
- Netwerkconfiguratie kan aangepast worden via scriptparameters of handmatig in het netwerkbestand.

# Functionele Aanbevelingen voor Home Assistant GitHub Repos

Een overzicht van interessante Home Assistant repositories met uitleg, gebruikssuggesties en directe links.

---

## 1. **HA-MCP (AI Model Context Protocol)**
**Repo:** [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp)  
**Functionaliteit:**
- Maakt Home Assistant aanstuurbaar via natuurlijke taal door AI-modellen.
- Ondersteunt meerdere AI-assistenten (Claude, GPT, Cursor, enz.).
- Kan apparaten schakelen, statussen opvragen, dashboards aanpassen en automatiseringen creëren.

**Aanbeveling:**
- Ideaal voor gebruikers die AI-integratie willen toevoegen aan HA.
- Geschikt voor geavanceerde automatiseringen en AI-gestuurde dashboards.
- Let op privacy: sommige AI-opties vereisen cloud-connecties.

---

## 2. **Home Assistant Naming Convention**
**Repo:** [Trikos/Home-Assistant-Naming-Convention](https://github.com/Trikos/Home-Assistant-Naming-Convention)  
**Functionaliteit:**
- Richtlijnen voor consistente, overzichtelijke entity-naamgeving.
- Voorbeeldconventie: `domain.location_deviceType_function_identifier`

Bijvoorbeeld: `sensor.livingroom_temperature_main`.

**Aanbeveling:**
- Onmisbaar voor grotere HA-installaties.
- Vergemakkelijkt automatiseringen, dashboardgebruik en onderhoud.
- Aan te raden om vanaf het begin consequent te implementeren.

---

## 3. **Curated en inspirerende resources**

| Repo | Functionaliteit | Aanbeveling |
|------|----------------|-------------|
| [frenck/awesome-home-assistant](https://github.com/frenck/awesome-home-assistant) | Verzameling van integraties, automations, dashboard cards en community tools | Perfect om inspiratie op te doen en nieuwe tools te ontdekken |
| [alexbelgium/hassio-addons](https://github.com/alexbelgium/hassio-addons) | Extra add-ons zoals Filebrowser, Portainer, VPN, Node-RED | Breidt HA-functionaliteit uit met kant-en-klare add-ons |
| [HA Community Add-ons](https://github.com/hassio-addons/repository) | Officiële community add-ons | Gemakkelijk extra services toevoegen aan HA |
| [frigate](https://github.com/blakeblackshear/frigate) | NVR met object detection voor camera’s | Voor geavanceerde beveiliging en automatisering van camera’s |
| [awesome-ha-blueprints](https://community.home-assistant.io/t/awesome-ha-blueprints/256687) | Community automation templates | Bespaart tijd bij het maken van complexe automatiseringen |
| [ha_xiaomi_home](https://github.com/rytilahti/python-miio) | Integratie van Xiaomi-apparaten | Voor gebruikers van Xiaomi sensoren, schakelaars en domotica |
| [Zigbee2MQTT](https://github.com/Koenkk/zigbee2mqtt) | Zigbee-apparaten integratie via MQTT | Voor Zigbee-apparaten zonder specifieke vendor bridge |
| [ESPHome](https://github.com/esphome/esphome) | Creëer en beheer custom ESP8266/ESP32 apparaten | Voor DIY-sensoren en slimme apparaten |

---

## 4. **Aanbevelingen voor praktisch gebruik**
- Gebruik **HACS** (Home Assistant Community Store) om veel custom integrations en dashboard cards eenvoudig te installeren.  
[HACS website](https://hacs.xyz/)
- Combineer **Naming Convention** met **HA-MCP** voor een schaalbare en AI-gestuurde setup.
- Bekijk **awesome-home-assistant** en community blueprints voor inspiratie en best practices.
- Overweeg **add-ons** zoals Portainer, Node-RED en VPN om HA te verbeteren en makkelijker te beheren.
- Experimenteer met camera- en beveiligingstools zoals **Frigate** voor een veilig en geautomatiseerd huis.
