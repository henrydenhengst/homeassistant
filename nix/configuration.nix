{ config, pkgs, ... }:

let
  homelabDir = "/srv/homelab";
in

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.grub.device = "/dev/sda";
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";

  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "docker" "network" ];
    password = "changeme"; # vervang door veilig wachtwoord
  };

  security.wheelNeedsPassword = false;

  # -------------------------------
  # Docker & Compose
  # -------------------------------
  services.docker.enable = true;
  virtualisation.docker-compose.enable = true;

  # -------------------------------
  # Systeem packages inclusief git/vim
  # -------------------------------
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
    git
    vim
  ];

  nixpkgs.config.allowUnfree = true;

  # -------------------------------
  # Maak homelab folders aan
  # -------------------------------
  systemd.tmpfiles.rules = [
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

  # -------------------------------
  # Extra services
  # -------------------------------
  services.openssh.enable = true;
  services.firewall.enable = true;
}