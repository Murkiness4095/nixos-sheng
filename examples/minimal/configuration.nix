{ lib, ... }:
{
  # mkForce also permits inheriting the upstream sheng-dual configuration,
  # whose hostname is explicitly set to sheng-dual.
  networking.hostName = lib.mkForce "sheng";

  # Default constructor: SINGLE system, root PARTLABEL=userdata.
  # On an existing dual-system device, either uncomment the next line OR
  # inherit nixosConfigurations.sheng-dual as shown in README.md.
  # sheng.rootfs.partlabel = "linux";

  # Keep this value when upgrading NixOS; it describes installation defaults.
  system.stateVersion = "26.11";

  # Keep USB serial access during hardware bring-up.
  services.shengSerialConsole.enable = true;

  # Add personal packages, users and desktop configuration here.
  # The hardware input already defines the userdata root filesystem,
  # kernel, firmware and extlinux generation installer.
}
