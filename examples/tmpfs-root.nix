# Optional NixOS module for an EXISTING sheng ext4 installation.
# Import alongside the board module, supplying inputs via specialArgs or
# adapting this function to your own flake's module structure.
{ inputs, ... }:
{
  imports = [ inputs.preservation.nixosModules.default ];

  sheng.rootfs.tmpfsRoot.enable = true;

  # Reuse the old root's state in place: no move, copy, format or repartition.
  # /nix, /persist, /home and /boot are bound by the board's tmpfs module.
  preservation = {
    enable = true;
    preserveAt."/sysroot-storage" = {
      directories = [
        "/var"
        "/root"
        "/etc/ssh"
        "/etc/NetworkManager/system-connections"
        "/etc/nixos"
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
      ];
    };
  };
  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
}
