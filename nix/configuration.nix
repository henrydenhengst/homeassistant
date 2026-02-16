{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ---------------------------
  # Basis systeem
  # ---------------------------
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";

  boot.loader.grub.device = "/dev/sda";

  nixpkgs.config.allowUnfree = true;

  # ---------------------------
  # User
  # ---------------------------
  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    initialPassword = "changeme";
  };

  security.sudo.wheelNeedsPassword = false;

  # ---------------------------
  # Docker
  # ---------------------------
  virtualisation.docker.enable = true;

  # ---------------------------
  # Essentials only
  # ---------------------------
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    usbutils

    # Firmware (voor Zigbee / BLE / WiFi dongles)
    firmware-linux
    firmware-linux-nonfree
    firmware-iwlwifi
    firmware-realtek
    bluez
    bluez-firmware
  ];

  # ---------------------------
  # SSH
  # ---------------------------
  services.openssh.enable = true;

  # ---------------------------
  # Firewall
  # ---------------------------
  networking.firewall.enable = true;

  # ---------------------------
  # Homelab directories
  # ---------------------------
  systemd.tmpfiles.rules = [
    "d /srv/homelab 0755 homelab homelab -"
  ];
}