{ config, pkgs, ... }:

let
  homelabDir = "/srv/homelab";
in
{
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";

  users.users.root.initialPassword = "changeme"; # pas veilig aan
  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    password = "changeme"; # pas veilig aan
  };

  security.sudo.enable = true;

  ##############################
  # HARDWARE / FIRMWARE
  ##############################
  hardware.enableAllFirmware = true;
  services.bluetooth.enable = true;

  # Zigbee CH340 altijd /dev/zigbee
  services.udev.rules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="zigbee"
  '';

  ##############################
  # DOCKER
  ##############################
  virtualisation.docker.enable = true;
  virtualisation.docker.compose.enable = true;
  virtualisation.docker.enableDockerRootless = false;
  systemd.services.docker.enable = true;

  ##############################
  # FIREWALL
  ##############################
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 1880 1883 3000 3001 8080 8081 8086 9000 9443 8000 8001 ];

  ##############################
  # PERSISTENT VOLUMES & AUTOMATISCHE FOLDERCREATIE
  ##############################
  environment.systemPackages = with pkgs; [
    git vim curl wget nano docker-compose
  ];

  system.activationScripts.createHomelabDirs = ''
    mkdir -p ${homelabDir}/{homeassistant,mariadb,mosquitto,portainer,beszel,homepage,uptime-kuma,node-red,grafana,influxdb,dozzle,it-tools,duckdns,gotify}
    chown -R homelab:homelab ${homelabDir}
  '';

  # Automatisch .env genereren
  system.activationScripts.createEnvFile = ''
    cat > ${homelabDir}/.env <<EOF
TZ=Europe/Amsterdam
MYSQL_ROOT_PASSWORD=homeassistantroot
MYSQL_DATABASE=homeassistant
MYSQL_USER=homeassistant
MYSQL_PASSWORD=homeassistant
EOF
    chown homelab:homelab ${homelabDir}/.env
  '';

  ##############################
  # OPTIONAL SERVICES
  ##############################
  services.openssh.enable = true;

  systemd.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
  '';
}