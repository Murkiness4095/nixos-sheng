{
  description = "Personal NixOS configuration for Xiaomi Pad 6S Pro";

  inputs.nixos-sheng.url = "github:Murkiness4095/nixos-sheng";

  outputs = { nixos-sheng, ... }: {
    # Single system: userdata root and the sheng-esp partition mounted at /efi.
    nixosConfigurations.sheng = nixos-sheng.nixosConfigurations.sheng-efi-generations.extendModules {
      modules = [ ./configuration.nix ];
    };

    # Android/NixOS dual boot: use #sheng-dual-efi and keep userdata for Android.
    nixosConfigurations.sheng-dual-efi = nixos-sheng.nixosConfigurations.sheng-dual-efi-generations.extendModules {
      modules = [ ./configuration.nix ];
    };
  };
}
