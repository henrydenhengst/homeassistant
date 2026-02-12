
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