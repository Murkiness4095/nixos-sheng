# ---
# Module: Sheng Noctalia Brightness
# Description: Platform facts needed to drive sheng's panel backlight from Noctalia
# Scope: System
# Notes:
# - Noctalia only auto-binds a backlight whose sysfs parent device lives under a
#   DRM connector, or when the output name starts with eDP. sheng's backlight is
#   an I2C ktz8866 chip next to a DSI panel, so without an explicit mapping the
#   shell logs "skipping backlight 'ktz8866-backlight' because it could not be
#   matched to an active output" and offers no display brightness control.
# - Noctalia reads exactly one user-level config file (no config.d, no
#   XDG_CONFIG_DIRS merge), so a shared user configuration has to carry the
#   [brightness.monitor.*] section; consume these options instead of hardcoding
#   the values per device.
# - This module deliberately installs no file: user configuration directories on
#   this device are symlinks into the user's own nix-config, and seeding them
#   here would fight that layout.
# ---
{ config, lib, ... }:

{
  options.sheng.noctalia.brightness = {
    connector = lib.mkOption {
      type = lib.types.str;
      default = "DSI-1";
      description = ''
        Noctalia output selector for sheng's panel. Noctalia matches this against
        the Wayland connector name (see {command}`wlr-randr`).
      '';
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "ktz8866-backlight";
      description = ''
        sysfs backlight device name as it appears in
        {file}`/sys/class/backlight`.
      '';
    };

    config = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = ''
        [brightness.monitor.${config.sheng.noctalia.brightness.connector}]
        backend = "backlight"
        backlight_device = "${config.sheng.noctalia.brightness.device}"
      '';
      description = ''
        Ready-to-append Noctalia TOML snippet for the values above.
      '';
    };
  };
}
