# Defaults for downloadable desktop images only, not the board module or
# personal shengSystem configurations. PipeWire refuses root user sessions.
{ lib, ... }:
{
  users.users.nixos = {
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
    user = lib.mkDefault "nixos";
  };

  services.pulseaudio.enable = lib.mkDefault false;
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };
}
