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

  # DISABLED: Setting GRUB on a tmpfs root causes build failures
  boot.loader.grub.enable = false; 
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
  # REMOVED: Manual fileSystems."/" and "/home" entries to avoid 
  # conflicts with the auto-detected tmpfs settings.
  
  # REMOVED: Swapfile (Caused 'No space left on device' on tmpfs)
  swapDevices = [ ]; 

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
    # REMOVED: Individual firmware names (they are undefined variables)
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
  boot.tmp.cleanOnBoot = true; # Renamed from cleanTmpDir.enable
  hardware.enableAllFirmware = true;
  
  # Added to fix mandatory version warning
  system.stateVersion = "24.11"; 
}
