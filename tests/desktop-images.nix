# Evaluated by both image workflows against their checked-out Git flake.
{ flake }:
let
  check =
    name: root:
    let
      c = flake.nixosConfigurations.${name}.config;
      user = c.services.displayManager.autoLogin.user;
    in
    assert c.services.displayManager.autoLogin.enable;
    assert user != "root";
    assert c.users.users.${user}.isNormalUser;
    assert c.services.pipewire.enable && c.services.pipewire.pulse.enable;
    assert c.services.pipewire.wireplumber.enable && c.security.rtkit.enable;
    assert c.networking.hostName == name;
    assert c.sheng.rootfs.partlabel == root;
    {
      inherit user;
      hostname = c.networking.hostName;
      root = c.sheng.rootfs.partlabel;
    };
in
{
  singleKde = check "sheng-kde" "userdata";
  singleGnome = check "sheng-gnome" "userdata";
  dualKde = check "sheng-dual-kde" "linux";
  dualGnome = check "sheng-dual-gnome" "linux";
  cliUnchanged =
    assert !(flake.nixosConfigurations.sheng.config.users.users ? nixos);
    assert !(flake.nixosConfigurations.sheng-dual.config.users.users ? nixos);
    true;
}
