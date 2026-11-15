{ lib, ... }:
{
  # mkForce also permits inheriting the upstream sheng-dual configuration,
  # whose hostname is explicitly set to sheng-dual.
  networking.hostName = lib.mkForce "sheng";

  # Select #sheng (userdata) or #sheng-dual-efi (linux) in flake.nix.
  # Both targets mount sheng-esp at /efi.
  # Keep this value when upgrading NixOS; it describes installation defaults.
  system.stateVersion = "26.11";

  # Keep USB serial access during hardware bring-up.
  services.shengSerialConsole.enable = true;

  # Add personal packages, users and desktop configuration here.
  # The hardware input already defines the selected root filesystem,
  # kernel, firmware and systemd-boot generation installer.
}
