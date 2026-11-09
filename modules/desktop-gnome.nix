# Minimal but usable GNOME image for sheng.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.desktopManager.gnome.enable = true;

  # Desktop images provide Firefox through desktop-image.nix.
  environment.gnome.excludePackages = [ pkgs.epiphany ];

  services.displayManager.gdm.enable = true;

  services.libinput.enable = lib.mkDefault true;
}
