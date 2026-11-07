# Optional NixOS module for an EXISTING sheng ext4 installation.
# Supply inputs and user through your own specialArgs/_module.args, or import
# this function explicitly with { inherit inputs; user = yourConfiguredUser; }.
# This is a starting allowlist, not a guarantee for every service/application.
{ inputs, user, ... }:
{
  imports = [ inputs.preservation.nixosModules.default ];

  sheng.rootfs.tmpfsRoot = {
    enable = true;
    persistHome = false;
  };

  # Existing data is reused in place; no move, copy, format or repartition.
  # The board binds /nix, /persist and /boot. /home is volatile by default.
  preservation = {
    enable = true;
    preserveAt."/sysroot-storage" = {
      directories = [
        # System identity, accounts and network state.
        "/var/lib/nixos"
        "/var/lib/AccountsService"
        "/var/lib/NetworkManager"
        {
          directory = "/var/lib/bluetooth";
          mode = "0700";
        }
        "/var/lib/systemd"
        "/var/lib/hjem"
        # DynamicUser services (e.g. mihomo) keep their state here.
        {
          directory = "/var/lib/private";
          mode = "0700";
        }
        # sheng sensor registry, fingerprint and trusted-service state.
        "/var/lib/qcom"
        {
          directory = "/var/lib/fpc1553";
          mode = "0700";
        }
        {
          directory = "/var/lib/fprint";
          mode = "0700";
        }
        {
          directory = "/var/lib/qtee_supplicant";
          mode = "0700";
        }
        {
          directory = "/var/lib/tee";
          mode = "0700";
        }
        "/etc/ssh"
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        }
        "/etc/nixos"
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
      ];
      users.${user} = {
        directories = [
          "Documents"
          "Pictures"
          {
            directory = ".ssh";
            mode = "0700";
          }
          # Add actual per-application data paths here. Do not persist all
          # of .config/.local/.cache merely to avoid auditing applications.
        ];
      };
    };
  };
  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
}
