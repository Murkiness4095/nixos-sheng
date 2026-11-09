# Defaults for downloadable desktop images only, not personal board configs.
{ config, lib, ... }:
let
  cfg = config.sheng.desktop;
in
{
  options.sheng.desktop.userName = lib.mkOption {
    type = lib.types.addCheck lib.types.str (
      name: name != "root" && builtins.match "[a-z_][a-z0-9_-]{0,30}" name != null
    );
    default = (import ../image-settings.nix).userName;
    description = "Regular desktop image account; also used for GUI autologin.";
  };

  config = {
    programs.firefox.enable = lib.mkDefault true;

    users.users.${cfg.userName} = {
      isNormalUser = true;
      description = "NixOS desktop user";
      initialPassword = lib.mkDefault "nixos";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "render"
        "input"
      ];
    };
    services.displayManager.autoLogin = {
      enable = lib.mkDefault true;
      user = lib.mkDefault cfg.userName;
    };
    services.pulseaudio.enable = lib.mkDefault false;
    security.rtkit.enable = lib.mkDefault true;
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = lib.mkDefault true;
    };
  };
}
