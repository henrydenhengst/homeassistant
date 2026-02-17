{ config, pkgs, ... }:

{
  # ------------------------
  # Hardware detection
  # ------------------------
  imports = [ ./hardware-configuration.nix ];

  # ------------------------
  # Basic system settings
  # ------------------------
  networking.hostName = "homelab";
  time.timeZone = "Europe/Amsterdam";

  # AANGEPAST: Voor een echte SSD installatie moet GRUB AAN staan!
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # Installeer op de fysieke schijf
  
  nixpkgs.config.allowUnfree = true;

  users.users.homelab = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    initialPassword = "changeme";
  };
  security.sudo.wheelNeedsPassword = false;

  # ------------------------
  # File systems & Optimization
  # ------------------------
  # De fileSystems blokken zijn hier weggehaald omdat ze al in de 
  # hardware-configuration.nix staan die je script genereert.
  
  swapDevices = [ ]; # Leeg laten om "No space" errors tijdens build te voorkomen

  systemd.timers.fstrim.enable = true;

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
  ];

  # ------------------------
  # SSH & firewall
  # ------------------------
  services.openssh.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 8123 1883 ];

  # ------------------------
  # Homelab folders
  # ------------------------
  systemd.tmpfiles.rules = [
    "d /srv/homelab 0755 homelab homelab -"
  ];

  # ------------------------
  # Auto-upgrades
  # ------------------------
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  # ------------------------
  # Misc & Fixes
  # ------------------------
  boot.tmp.cleanOnBoot = true;
  hardware.enableAllFirmware = true;
  
  system.stateVersion = "24.11"; 
}
