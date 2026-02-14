// homelab-full-mermaid.js

const homelabMermaid = `
flowchart TD
    %% Home Automation Core
    HA[Home Assistant]
    Z2M[Zigbee2MQTT<br>(Zigbee USB)]
    ZWave[Z-Wave JS<br>(Z-Wave USB)]
    BLE2MQTT[BLE2MQTT<br>(BLE devices)]
    MQTTIR[MQTT-IR / Beszel Hub<br>(IR devices)]
    P1[Smart Meter P1 Monitor / Uptime-Kuma]
    Mosq[Mosquitto<br>MQTT Broker]

    %% Databases
    MariaDB[MariaDB<br>HA DB]
    Influx[InfluxDB<br>Metrics DB]

    %% Dashboards / Monitoring
    Grafana[Grafana<br>Dashboard]
    RedNode[RedNode<br>Flow Editor]
    Beszel[Beszel Hub + Agent]
    Homepage[Homepage Dashboard]
    Uptime[Uptime-Kuma<br>Alerts]
    IT[IT-Tools<br>Diagnostics]

    %% Additional Services
    Portainer[Portainer<br>Docker Management]
    Dozzle[Dozzle<br>Container Logs]
    DuckDNS[DuckDNS<br>Dynamic DNS]
    CrowdSec[CrowdSec<br>Security Monitoring]
    Watchtower[Watchtower<br>Auto Container Updates]

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

    %% Styling (optioneel)
    classDef db fill:#f9f,stroke:#333,stroke-width:1px;
    classDef dashboard fill:#9f9,stroke:#333,stroke-width:1px;
    classDef service fill:#ff9,stroke:#333,stroke-width:1px;
    class MariaDB,Influx db
    class Grafana,RedNode,Beszel,Homepage,Uptime,IT dashboard
    class Portainer,Dozzle,DuckDNS,CrowdSec,Watchtower service
`;

export default homelabMermaid;