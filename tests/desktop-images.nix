# Evaluated by both image workflows against their checked-out Git flake.
{ flake }:
let
  check =
    name: root:
    let
      c = flake.nixosConfigurations.${name}.config;
      user = c.services.displayManager.autoLogin.user;
      browsers = builtins.filter (
        name:
        builtins.elem name [
          "firefox"
          "epiphany"
        ]
      ) (builtins.map (p: p.pname or p.name) c.environment.systemPackages);
    in
    assert c.services.displayManager.autoLogin.enable;
    assert user != "root";
    assert user == (import ../image-settings.nix).userName;
    assert c.users.users.${user}.isNormalUser;
    assert c.services.pipewire.enable && c.services.pipewire.pulse.enable;
    assert c.services.pipewire.wireplumber.enable && c.security.rtkit.enable;
    assert c.programs.firefox.enable;
    assert builtins.elem "firefox" browsers;
    assert !(builtins.elem "epiphany" browsers);
    assert c.networking.hostName == name;
    assert c.sheng.rootfs.partlabel == root;
    {
      inherit user browsers;
      hostname = c.networking.hostName;
      root = c.sheng.rootfs.partlabel;
    };
in
{
  singleKde = check "sheng-kde" "userdata";
  singleGnome = check "sheng-gnome" "userdata";
  dualKde = check "sheng-dual-kde" "linux";
  dualGnome = check "sheng-dual-gnome" "linux";
  customUser =
    let
      c =
        (flake.nixosConfigurations.sheng-dual-kde.extendModules {
          modules = [ { sheng.desktop.userName = "tablet"; } ];
        }).config;
    in
    assert c.services.displayManager.autoLogin.user == "tablet";
    assert c.users.users.tablet.isNormalUser;
    assert !(c.users.users ? nixos);
    assert c.sheng.rootfs.partlabel == "linux";
    true;
  cliUnchanged =
    assert !(flake.nixosConfigurations.sheng.config.users.users ? nixos);
    assert !(flake.nixosConfigurations.sheng-dual.config.users.users ? nixos);
    assert !flake.nixosConfigurations.sheng.config.programs.firefox.enable;
    assert !flake.nixosConfigurations.sheng-dual.config.programs.firefox.enable;
    true;
}
