// homelab-mermaid.js

const homelabMermaid = `
flowchart TD
    HA[Home Assistant]
    Z2M[Zigbee2MQTT<br>(Zigbee USB)]
    ZWave[Z-Wave JS<br>(Z-Wave USB)]
    Mosq[Mosquitto MQTT Broker]
    MariaDB[MariaDB<br>(HA DB)]
    Influx[InfluxDB<br>Metrics DB]
    Grafana[Grafana<br>Dashboard]
    RedNode[RedNode<br>Flow Editor]
    Beszel[Beszel Hub + Agent]
    Homepage[Homepage Dashboard]
    Uptime[Uptime-Kuma<br>Alerts]
    IT[IT-Tools<br>Diagnostics]

    %% Connect devices to MQTT
    Z2M -->|MQTT| Mosq
    ZWave -->|MQTT| Mosq
    HA -->|MQTT| Mosq

    %% Databases
    Mosq --> MariaDB
    Mosq --> Influx

    %% Dashboards & Automation
    MariaDB --> Grafana
    Influx --> Grafana
    Grafana --> Beszel
    Grafana --> RedNode
    RedNode --> Homepage
    Beszel --> Homepage
    Beszel --> Uptime
    Homepage --> IT
`;

export default homelabMermaid;