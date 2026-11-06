{ ... }:
{
  networking.hostName = "sheng";

  # Keep this value when upgrading NixOS; it describes installation defaults.
  system.stateVersion = "26.11";

  # Keep USB serial access during hardware bring-up.
  services.shengSerialConsole.enable = true;

  # Add personal packages, users and desktop configuration here.
  # The hardware input already defines the userdata root filesystem,
  # kernel, firmware and extlinux generation installer.
}
