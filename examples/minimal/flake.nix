{
  description = "Personal NixOS configuration for Xiaomi Pad 6S Pro";

  inputs.nixos-sheng.url = "github:Murkiness4095/nixos-sheng";

  outputs = { nixos-sheng, ... }: {
    nixosConfigurations.sheng = nixos-sheng.lib.shengSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
