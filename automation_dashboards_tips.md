# ⭐ Populairste Home Assistant GitHub Projecten

Hier zijn een paar van de meest gebruikte en gevolgde Home Assistant–gerelateerde projecten binnen de community.

---

## 🏠 Core Platform

- **0 – Core repositories**
  - `home-assistant/core` → Hoofd Home Assistant software  
  - `home-assistant/frontend` → UI / dashboard  
  - `home-assistant/supervisor` → OS / add-on beheer  

👉 Dit is de basis waar vrijwel alle automations op draaien.

---

## 🧩 Community Uitbreidingen / Automation Ecosystem

- **1**
  - Community Store voor custom integrations, cards en themes  
  - Wordt door veel homelabs gebruikt voor automations & UI uitbreiding  

---

## 🔌 Device / Automation Ecosystem (Zeer populair in homelabs)

- **2**
  - Automations via ESP32 / ESP8266  
  - Veel gebruikt voor sensoren, relais, BLE proxy’s  

- **3**
  - Zigbee devices volledig lokaal via MQTT  
  - Groot community automation ecosysteem  

---

## 📦 Config / Automation Voorbeeld Repositories (Community Favorieten)

Niet core, maar wel populair bij power users:

- Complete Home Assistant configuraties  
- Blueprint collecties (automation templates)  
- Custom component bundels  

Typische zoektermen op **4**:

home assistant config home assistant blueprints home assistant automations

---

## 💡 Wat “Populair” Betekent in de Home Assistant Community

Meestal gebaseerd op:

- ⭐ GitHub stars  
- 📦 Wordt veel via HACS geïnstalleerd  
- 🧠 Vaak genoemd op Reddit / forums / Discord  
- 🔧 Gebruikt in YouTube homelab setups  

---

## 🔥 Praktische Top voor Homelabs

Als je maar een paar kiest, kies meestal:

1. Home Assistant Core  
2. HACS  
3. ESPHome  
4. Zigbee2MQTT  

👉 Daarmee dek je ±80% van alle Home Assistant automation setups af.

# ⭐ Populairste Home Assistant Dashboard GitHub Projecten

Hier zijn een paar van de meest gebruikte en bekeken dashboard-projecten binnen de Home Assistant community.

---

## 🖥️ Complete Dashboard Projecten

### 1. Dwains Lovelace Dashboard
- Platform: 0  
- Maker: 1  
- Waarom populair:
  - Auto genereert dashboards op basis van Home Assistant entities  
  - Werkt goed op tablet dashboards en wall panels  
  - Plug & play voor beginners  

---

### 2. Mushroom Dashboard Ecosystem
- Maker: 2  
- Waarom populair:
  - Moderne minimalistische UI  
  - Zeer populair samen met HACS  
  - Veel gebruikt in nieuwe Home Assistant setups  

---

### 3. Madelena Home Assistant Config
- Maker: 3  
- Waarom populair:
  - Zeer geavanceerde dashboards  
  - Veel inspiratie voor power users  
  - Ambient / wall display stijl  

---

### 4. Home Assistant Mobile First Dashboard
- Maker: 4  
- Waarom populair:
  - Ontworpen voor telefoon gebruik  
  - Snel en clean  
  - Ideaal als je vooral mobiel Home Assistant gebruikt  

---

### 5. Adaptive Mushroom Dashboard Packs
- Maker: 5  
- Waarom populair:
  - Responsive layouts  
  - Combineert Mushroom cards tot complete dashboards  
  - Veel gebruikt in moderne homelabs  

---

## 🧠 Wat de Community Meestal Gebruikt

Typische stack:

- Home Assistant Core  
- HACS  
- Mushroom Cards  
- Custom dashboard repo (zoals hierboven)  

---

## 💡 Tip voor Startende Homelabs

Meest gekozen combinatie:

👉 Mushroom Cards + eigen Lovelace dashboard  
👉 Of Dwains als “auto dashboard” startpunt


# 🏷️ Home Assistant Naming Convention

Deze naming convention zorgt voor consistente, schaalbare en leesbare namen binnen je Home Assistant omgeving.  
Dit maakt debugging, dashboards, automatiseringen en MQTT-integraties veel eenvoudiger.


**GitHub Repository:** [Trikos / Home-Assistant-Naming-Convention](https://github.com/Trikos/Home-Assistant-Naming-Convention)

---

## 🎯 Basis Principe

**Structuur:**  
`area.device_function`

**Voorbeelden:**

- `sensor.woonkamer_temperatuur`
- `light.keuken_spots`
- `switch.server_rack_power`

---

## 📦 Entities

### Sensors
Prefix: `sensor.`

**Voorbeelden:**

- `sensor.woonkamer_temperatuur`
- `sensor.slaapkamer_luchtvochtigheid`
- `sensor.server_cpu_temp`

---

### Binary Sensors
Prefix: `binary_sensor.`

**Voorbeelden:**

- `binary_sensor.voordeur_contact`
- `binary_sensor.garage_beweging`
- `binary_sensor.server_rack_deur`

---

### Lights
Prefix: `light.`

**Voorbeelden:**

- `light.woonkamer_plafond`
- `light.keuken_spots`
- `light.tuin_padverlichting`

---

### Switches
Prefix: `switch.`

**Voorbeelden:**

- `switch.server_rack_fan`
- `switch.printer_power`
- `switch.tv_stekker`

---

## 🤖 Automations
Prefix: `automation.`

**Voorbeelden:**

- `automation.licht_aan_bij_beweging_hal`
- `automation.verwarming_eco_nacht`
- `automation.notificatie_wasmachine_klaar`

---

## 📜 Scripts
Prefix: `script.`

**Voorbeelden:**

- `script.alles_uit_slapen`
- `script.film_kijken_scene`
- `script.server_onderhoud_mode`

---

## 📡 MQTT Naming (Aanbevolen)
**Structuur:**  
`home/<area>/<device>/<function>`

**Voorbeelden:**

- `home/woonkamer/thermostaat/temperatuur`
- `home/garage/deur/contact`
- `home/server/rack/temperatuur`

---

## 📊 Dashboard Friendly Naming
Gebruik korte maar duidelijke namen voor Lovelace dashboards of widgets:

- `woonkamer_temp`
- `garage_deur`
- `server_cpu`

---

## 🚀 Best Practices

- ✅ Gebruik altijd lowercase  
- ✅ Gebruik underscores `_` in plaats van spaties  
- ✅ Houd consistente area namen aan  
- ✅ Vermijd afkortingen, tenzij standaard (cpu, ram, temp)  
- ✅ Houd namen logisch voor dashboards én automations  

---

## 🧠 Tip voor Grote Homelabs
Gebruik vaste area namen zoals:

- `woonkamer`
- `keuken`
- `slaapkamer`
- `badkamer`
- `garage`
- `tuin`
- `server`
- `netwerk`


Wil je terug naar de hoofddocumentatie van je Homelab-stack?  
Klik hier: [README.md](./README.md)