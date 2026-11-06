{
  description = "Personal sheng configuration using flake-parts";

  inputs = {
    nixos-sheng.url = "github:Murkiness4095/nixos-sheng";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" ];
      imports = [ (inputs.import-tree ./modules) ];
    };
}
