# Minimal but usable KDE Plasma 6 image for sheng.
#
# This is intentionally layered on top of the normal board modules: it only
# enables the desktop stack and leaves kernel, firmware, touch, audio and
# first-boot store registration unchanged.
{ config, lib, pkgs, ... }:

{
  services.xserver.enable = lib.mkDefault true;

  services.desktopManager.plasma6.enable = true;
  services.desktopManager.plasma6.enableQt5Integration = false;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.enableHidpi = true;

  # The board's touchscreen and pen are already handled by the base modules.
  services.libinput.enable = lib.mkDefault true;
}
