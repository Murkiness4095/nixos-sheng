{ inputs, self, ... }:
{
  # Single system: userdata root and the sheng-esp partition mounted at /efi.
  flake.nixosConfigurations.sheng = inputs.nixos-sheng.nixosConfigurations.sheng-efi-generations.extendModules {
    modules = [ self.nixosModules.node-sheng ];
  };

  # Android/NixOS dual boot: use #sheng-dual-efi and keep userdata for Android.
  flake.nixosConfigurations.sheng-dual-efi = inputs.nixos-sheng.nixosConfigurations.sheng-dual-efi-generations.extendModules {
    modules = [ self.nixosModules.node-sheng ];
  };

  # Use these targets for regular images and existing extlinux installations.
  flake.nixosConfigurations.sheng-extlinux = inputs.nixos-sheng.nixosConfigurations.sheng.extendModules {
    modules = [ self.nixosModules.node-sheng ];
  };
  flake.nixosConfigurations.sheng-dual-extlinux = inputs.nixos-sheng.nixosConfigurations.sheng-dual.extendModules {
    modules = [ self.nixosModules.node-sheng ];
  };

  flake.nixosModules.node-sheng = { lib, ... }: {
    # Add architecture-independent modules from your own configuration here.
    # The upstream EFI configurations already import board support.
    imports = [ ];

    networking.hostName = lib.mkForce "sheng";
    services.shengSerialConsole.enable = true;
    system.stateVersion = "26.11";
  };
}
