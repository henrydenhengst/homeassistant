{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

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
  # Firmware voor USB dongles
  # ---------------------------
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    usbutils

    firmware-linux
    firmware-linux-nonfree
    firmware-iwlwifi
    firmware-realtek
    bluez
    bluez-firmware
  ];

  # ---------------------------
  # SSH toegang
  # ---------------------------
  services.openssh.enable = true;

  # ---------------------------
  # Firewall
  # ---------------------------
  networking.firewall.enable = true;

  # ---------------------------
  # Homelab folders
  # ---------------------------
  systemd.tmpfiles.rules = [
    "d /srv/homelab 0755 homelab homelab -"
  ];
}