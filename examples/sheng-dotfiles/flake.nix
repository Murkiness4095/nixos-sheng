{
  description = "Personal configuration for a Xiaomi Pad 6S Pro running Mobile NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-sheng.url = "github:DotRedstone/nixos-sheng?dir=nixos";
  };

  outputs = { nixpkgs, hjem, nixos-sheng, ... }@inputs:
    let
      system = "aarch64-linux";
    in
    {
      nixosConfigurations.sheng =
        nixos-sheng.lib.${system}.mkShengSystem [
          { _module.args.inputs = inputs; }
          hjem.nixosModules.default
          ./hosts/sheng/configuration.nix
          ({ ... }: {
            hjem.users.user.imports = [ ./home/user.nix ];
          })
        ];
    };
}
