{ config, pkgs, ... }:

let
  homelabDir = "/srv/homelab";
in

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  # -----------------------------
  # Basis NixOS settings
  # -----------------------------
  boot.loader.grub.device = "/dev/sda";
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";
  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "docker" "network" ];
    password = "changeme"; # vervang door veilig wachtwoord
  };

  # -----------------------------
  # Enable Docker
  # -----------------------------
  services.docker.enable = true;
  services.docker.extraOptions = "--iptables=false"; # optioneel
  virtualisation.docker-compose.enable = true;

  # -----------------------------
  # USB, Bluetooth & Zigbee firmware
  # -----------------------------
  environment.systemPackages = with pkgs; [
    firmware-linux
    firmware-linux-nonfree
    firmware-misc-nonfree
    firmware-iwlwifi
    firmware-realtek
    bluez
    bluez-firmware
    usbutils
    curl
    gnupg
    lsb-release
    ca-certificates
  ];

  # -----------------------------
  # Non-free firmware repository
  # -----------------------------
  nixpkgs.config.allowUnfree = true;

  # -----------------------------
  # Homelab folders
  # -----------------------------
  environment.etc."homelab".source = homelabDir;
  environment.etc."homelab".directoryMode = "0755";

  systemd.tmpfiles.rules = [
    # maak homelab folder en subfolders aan
    "d /srv/homelab 0755 homelab homelab -"
    "d /srv/homelab/homeassistant 0755 homelab homelab -"
    "d /srv/homelab/mariadb 0755 homelab homelab -"
    "d /srv/homelab/mosquitto 0755 homelab homelab -"
    "d /srv/homelab/node-red 0755 homelab homelab -"
    "d /srv/homelab/influxdb 0755 homelab homelab -"
    "d /srv/homelab/grafana 0755 homelab homelab -"
    "d /srv/homelab/uptime-kuma 0755 homelab homelab -"
    "d /srv/homelab/duckdns 0755 homelab homelab -"
    "d /srv/homelab/gotify 0755 homelab homelab -"
    "d /srv/homelab/portainer 0755 homelab homelab -"
    "d /srv/homelab/dozzle 0755 homelab homelab -"
    "d /srv/homelab/homepage 0755 homelab homelab -"
    "d /srv/homelab/beszel 0755 homelab homelab -"
    "d /srv/homelab/appdaemon 0755 homelab homelab -"
  ];

  # -----------------------------
  # Enable system services
  # -----------------------------
  services.openssh.enable = true;
  services.firewall.enable = true;

  # -----------------------------
  # Optional: USB permissions
  # -----------------------------
  security.wheelNeedsPassword = false;

  # -----------------------------
  # Extra: Docker auto-start
  # -----------------------------
  systemd.services.docker-wait = {
    description = "Start Docker after boot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker start";
      RemainAfterExit = true;
    };
  };
}
