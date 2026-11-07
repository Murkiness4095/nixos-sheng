{ inputs, self, ... }:
{
  flake.nixosConfigurations.sheng = inputs.nixos-sheng.lib.shengSystem {
    modules = [ self.nixosModules.node-sheng ];
  };

  # Dual-system alternative: REPLACE the constructor above with this,
  # rather than defining the same output twice. See README.md.
  # flake.nixosConfigurations.sheng =
  #   inputs.nixos-sheng.nixosConfigurations.sheng-dual.extendModules {
  #     modules = [ self.nixosModules.node-sheng ];
  #   };

  flake.nixosModules.node-sheng = { lib, ... }: {
    # Add architecture-independent modules from your own configuration here.
    # The shengSystem constructor already imports the complete board support.
    imports = [ ];

    # With lib.shengSystem, uncomment for a dual-system linux root.
    # Not needed when inheriting sheng-dual above.
    # sheng.rootfs.partlabel = "linux";

    networking.hostName = lib.mkForce "sheng";
    services.shengSerialConsole.enable = true;
    system.stateVersion = "26.11";
  };
}
