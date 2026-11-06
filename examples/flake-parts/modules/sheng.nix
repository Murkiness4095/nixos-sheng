{ inputs, self, ... }:
{
  flake.nixosConfigurations.sheng = inputs.nixos-sheng.lib.shengSystem {
    modules = [ self.nixosModules.node-sheng ];
  };

  flake.nixosModules.node-sheng = { ... }: {
    # Add architecture-independent modules from your own configuration here.
    # The shengSystem constructor already imports the complete board support.
    imports = [ ];

    networking.hostName = "sheng";
    services.shengSerialConsole.enable = true;
    system.stateVersion = "26.11";
  };
}
