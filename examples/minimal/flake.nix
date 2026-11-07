{
  description = "Personal NixOS configuration for Xiaomi Pad 6S Pro";

  inputs.nixos-sheng.url = "github:Murkiness4095/nixos-sheng";

  outputs = { nixos-sheng, ... }: {
    # Default: standalone NixOS, root PARTLABEL=userdata.
    # For dual boot, set partlabel = "linux" in configuration.nix, OR
    # replace this definition with the commented alternative below.
    nixosConfigurations.sheng = nixos-sheng.lib.shengSystem {
      modules = [ ./configuration.nix ];
    };

    # Dual-system alternative; do not define the same output twice.
    # Inherits PARTLABEL=linux; configuration.nix overrides the hostname.
    # nixosConfigurations.sheng =
    #   nixos-sheng.nixosConfigurations.sheng-dual.extendModules {
    #     modules = [ ./configuration.nix ];
    #   };
  };
}
