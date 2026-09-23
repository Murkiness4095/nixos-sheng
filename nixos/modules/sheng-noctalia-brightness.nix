# ---
# Module: Sheng Noctalia Brightness
# Description: Binds sheng's ktz8866 panel backlight to the DSI output for Noctalia
# Scope: System
# Notes:
# - Noctalia only auto-binds a backlight whose sysfs parent device lives under a
#   DRM connector (or when the output name starts with eDP). sheng's backlight is
#   an I2C ktz8866 chip next to a DSI panel, so without an explicit mapping the
#   shell logs "skipping backlight 'ktz8866-backlight' because it could not be
#   matched to an active output" and exposes no display brightness control.
# - Consume sheng.noctalia.brightness from a shared user configuration instead of
#   hardcoding the device name there; this option spells out the device facts.
# - The seed file is created only when missing, so values changed in the Noctalia
#   settings UI survive.
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.sheng.noctalia.brightness;

  api = pkgs.writeText "noctalia-brightness-config.toml" ''
    [brightness.monitor.${cfg.connector}]
    backend = "backlight"
    backlight_device = "${cfg.device}"
  '';

  noctaliaEnabled = config.programs.noctalia.enable or false;

  normalUsers = lib.filterAttrs (_: user: user.isNormalUser && user.home != null) config.users.users;

  seedRules = lib.concatLists (
    lib.mapAttrsToList (name: user: [
      "d ${user.home}/.config/noctalia 0755 ${name} users -"
      "C ${user.home}/.config/noctalia/config.toml 0644 ${name} users - ${api}"
    ]) normalUsers
  );
in
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
  };

  config = lib.mkIf noctaliaEnabled {
    # Noctalia's NixOS module offers no settings option and Noctalia reads only a
    # user-level config file (no XDG_CONFIG_DIRS fallback), so seed that file for
    # every normal user. tmpfiles `C` copies only when the destination is absent.
    systemd.tmpfiles.rules = seedRules;
  };
}
