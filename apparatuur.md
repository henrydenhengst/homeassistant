# 🔹 Home Assistant Apparaten Overzicht

| Categorie                | Voorbeeldapparaat                   | Verbinding        | Mogelijkheden / Automatisering                     |
|---------------------------|------------------------------------|-----------------|--------------------------------------------------|
| Slimme verlichting        | Philips Hue, LIFX, Ikea Tradfri    | Zigbee / Wi-Fi  | Aan/uit, dimmen, scenes, timers                  |
| Slimme thermostaten       | Nest, Tado, Honeywell              | Wi-Fi           | Temperatuurregeling, schema's, aanwezigheid      |
| Slimme stekkers / plugs   | Meross, BroadLink, Xiaomi           | Wi-Fi / BLE     | Aan/uit, energie-monitoring, schema's           |
| Slimme sensoren           | Temperatuur, luchtvochtigheid      | Zigbee / BLE    | Automatisering op basis van sensorwaarden       |
| Slimme deursloten         | Yale, Nuki, Danalock               | Z-Wave / BLE    | Deur openen/sluiten, aanwezigheid detectie     |
| Slimme camera's / deurbellen | Ring, Arlo, Reolink             | Wi-Fi           | Bewegingsdetectie, meldingen, snapshots        |
| Slimme rook-/CO2-melders  | Nest Protect, Xiaomi               | Wi-Fi / BLE     | Alarmmeldingen, automatisering veiligheid      |
| Slimme gordijn-/rolluikmotoren | Aqara, Zemismart              | Zigbee / Wi-Fi  | Openen/sluiten, tijdschema's                   |
| Slimme ventilatoren / luchtzuiveraars | Dyson, Xiaomi          | Wi-Fi / BLE     | Aan/uit, snelheid, luchtkwaliteit               |
| Slimme tuinapparaten      | Irrigatie, buitenlampen            | Wi-Fi / Zigbee  | Tijdschema, weersafhankelijk automatisering    |
| Slimme speakers / assistenten | Google Home, Alexa, Sonos        | Wi-Fi / BLE     | Aanwezigheidsdetectie, notificaties            |
| Elektrische apparaten met energie-monitor | Koffiezetapparaat, wasmachine | Wi-Fi / Plug   | Energie monitoring, aan/uit schema's            |
| Gezondheid & persoonlijke apparaten | Weegschaal, saturatiemeter  | BLE             | Automatisch logging, dashboards                 |
| Fitnesstrackers / smartwatches | Fitbit, Apple Watch            | BLE             | Aanwezigheid, activiteit logging               |
| Deur/raam sensoren        | Xiaomi, Aqara                      | Zigbee / BLE    | Open/dicht detectie, alarm                     |

# 🔹 Slimme apparaten voor Home Assistant

## Veelvoorkomende apparaten
- **Slimme verlichting** – Philips Hue, Ikea Tradfri, LIFX  
- **Slimme thermostaten** – Nest, Tado, Honeywell  
- **Slimme stekkers / plugs** – BroadLink, Meross, Xiaomi  
- **Slimme sensoren** – temperatuur, luchtvochtigheid, waterlek  
- **Slimme deursloten** – Yale, Nuki, Danalock  
- **Slimme camera’s / deurbellen** – Ring, Arlo, Reolink  

## Apparaten die je vaak vergeet
- **Slimme rook- & CO2-melders** – Nest Protect, Xiaomi  
- **Slimme gordijn- en rolluikmotoren** – Aqara, Zemismart  
- **Slimme ventilatoren / luchtzuiveraars** – Dyson, Xiaomi  
- **Slimme tuinapparaten** – irrigatiesystemen, slimme buitenlampen  
- **Slimme speaker / assistenten** – Google Home, Alexa, Sonos (aanwezigheidsdetectie)  
- **Elektrische apparaten met energie-monitor** – koffiezetapparaat, wasmachine via slimme stekker  

## Bluetooth (BLE) apparaten
- **Gezondheid & persoonlijke apparaten**  
  - Slimme weegschalen, bloeddrukmeters, saturatiemeters  
  - Fitnesstrackers / smartwatches  
- **Sensoren & comfort**  
  - Temperatuur- en luchtvochtigheidssensoren  
  - Deur/raam sensoren  
  - Waterleksensoren  
  - Lichtschakelaars / dimmers  
- **Audio & entertainment**  
  - Bluetooth speakers  
  - Headphones (aanwezigheidsdetectie)  
  - TV / soundbar afstandsbediening  
- **Huisdieren & leefomgeving**  
  - Slimme kattenluiken / hondenkluiken  
  - Aquarium sensoren  
  - Terrarium lampen / klimaatcontrole  
- **Energie & apparaten**  
  - Slimme stekkers / plugs  
  - Slimme lampen  
  - E-bike of elektrische scooter (batterijstatus via BLE)  

## Tips voor integratie in Home Assistant
1. **BLE2MQTT** – maakt bijna elk BLE-device zichtbaar via MQTT  
2. **Zigbee2MQTT / Z-Wave** – sommige apparaten hebben zowel Zigbee/BLE varianten  
3. **RSSI signalen** – gebruik BLE-sensoren voor aanwezigheid in kamers  
4. **Direct vs. gateway** – sommige BLE-apparaten vereisen een app of gateway (bijv. Xiaomi Gateway)  

> 💡 Veel apparaten in huis hebben al een Bluetooth- of slimme variant. Met BLE2MQTT, Zigbee2MQTT of directe integratie kun je ze volledig automatiseren in Home Assistant.