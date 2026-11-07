# Minimal but usable GNOME image for sheng.
{ config, lib, pkgs, ... }:

{
  services.desktopManager.gnome.enable = true;

  services.displayManager.gdm.enable = true;

  services.libinput.enable = lib.mkDefault true;
}
