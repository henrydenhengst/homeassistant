{ config, pkgs, ... }:

{
  # ------------------------
  # Hardware detection
  # ------------------------
  imports =
    [ ./hardware-configuration.nix ];

  # ------------------------
  # Basic system settings
  # ------------------------
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";

  boot.loader.grub.device = "/dev/sda";   # MBR bootloader voor oude BIOS
  nixpkgs.config.allowUnfree = true;

  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    initialPassword = "changeme";  # pas aan
  };
  security.sudo.wheelNeedsPassword = false;

  # ------------------------
  # File systems & SSD optimization
  # ------------------------
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [ "noatime" "defaults" ];
  };

  fileSystems."/home" = {
    device = "/dev/sda2";
    fsType = "ext4";
    options = [ "noatime" "defaults" ];
  };

  swapDevices = [ { device = "/swapfile"; size = 2 * 1024 * 1024 * 1024; } ];

  systemd.timers.fstrim.enable = true;  # automatisch TRIM

  # ------------------------
  # Docker
  # ------------------------
  virtualisation.docker.enable = true;

  # ------------------------
  # Packages / firmware / homelab tools
  # ------------------------
  environment.systemPackages = with pkgs; [
    git vim curl usbutils htop wget tmux
    docker-compose
    firmware-linux firmware-linux-nonfree firmware-iwlwifi firmware-realtek
    bluez bluez-firmware
  ];

  # ------------------------
  # SSH & firewall
  # ------------------------
  services.openssh.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 8123 1883 ]; # SSH, Home Assistant, MQTT

  # ------------------------
  # Homelab folders
  # ------------------------
  systemd.tmpfiles.rules = [
    "d /srv/homelab 0755 homelab homelab -"
  ];

  # ------------------------
  # Auto-upgrades (optioneel)
  # ------------------------
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  # ------------------------
  # Misc
  # ------------------------
  boot.cleanTmpDir.enable = true;
  hardware.enableAllFirmware = true;
}
