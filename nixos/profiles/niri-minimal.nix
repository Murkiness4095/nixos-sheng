# ---
# Module: Niri Minimal Profile
# Description: Minimal Niri compositor with Noctalia shell, thunar, alacritty and fuzzel
# Scope: System
# Notes:
# - Noctalia is enabled through the upstream NixOS module imported by the flake.
# - This profile deliberately disables Hjem integration so Noctalia runs
#   purely via its NixOS module and systemd user service.
# - Greetd is configured for auto-login only when the default-user profile is used.
# ---

{ config, lib, pkgs, ... }:

let
  autoLoginEnabled = config.services.displayManager.autoLogin.enable or false;
  autoLoginUser = config.services.displayManager.autoLogin.user or null;
  niriCommand = "${lib.getExe pkgs.niri}";
  tuigreetCommand = "${lib.getExe pkgs.tuigreet}";
in
{
  # Niri compositor from nixpkgs.
  programs.niri.enable = true;

  # Graphics stack.
  hardware.graphics.enable = true;

  # Noctalia prerequisites. NetworkManager is already enabled in configuration.nix;
  # the remaining services are enabled here for profile completeness.
  hardware.bluetooth.enable = lib.mkDefault true;
  services.upower.enable = lib.mkDefault true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # Default applications requested for the image.
  programs.thunar.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    fuzzel
    thunar

    # Browsers
    brave

    # Chat
    # (telegram-desktop removed: depends on tg_owt / qtwebengine which has no aarch64 cache)

    # Media
    kazumi
    celluloid # video
    imv # image
    ffmpegthumbnailer
    poppler
    libopenraw
    libgsf

    # Editor / KDE integration
    # (kate and plasma-integration removed: depend on qtspeech which has no aarch64 cache)

    # Tools
    localsend
    brightnessctl # Backlight control for Noctalia OSD and hardware keys

    # Clipboard
    wl-clipboard
    cliphist
    # (copyq removed: depends on qtspeech which has no aarch64 cache)

    # Screenshot
    grim
    slurp
    satty # annotation

    # Archive
    file-roller

    # Flatpak management
    bazaar
    warehouse

    # Theming
    nwg-look

    # Vibe Coding
    mcp-nixos
  ];

  # Greetd-based display manager. Tuigreet is the fallback greeter; auto-login
  # is driven by services.displayManager.autoLogin so the default-user profile
  # and downstream constructors behave consistently.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    restart = lib.mkIf autoLoginEnabled (lib.mkForce false);
    settings = lib.mkMerge [
      {
        default_session = {
          command = "${tuigreetCommand} --greeting 'NixOS sheng (niri)' --cmd ${niriCommand}";
          user = "greeter";
        };
      }
      (lib.mkIf autoLoginEnabled {
        initial_session = {
          command = niriCommand;
          user = autoLoginUser;
        };
      })
    ];
  };

  # Noctalia is enabled system-wide through the upstream NixOS module.
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
    systemd.enable = true;
  };

  # xdg-desktop-portal for Wayland file opening and screen sharing.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
  };

  # Ensure greetd owns the VT.
  services.kmscon.enable = lib.mkForce false;

  # Polkit is required by Noctalia and modern Wayland desktops.
  security.polkit.enable = lib.mkDefault true;

  # The base configuration already ignores suspend-related keys; keep the same
  # defaults for the Niri profile so the unreliable sheng kernel suspend path
  # is not triggered accidentally.
  services.logind.settings.Login.HandlePowerKey = lib.mkDefault "ignore";
  services.logind.settings.Login.HandleLidSwitch = lib.mkDefault "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = lib.mkDefault "ignore";
  services.logind.settings.Login.HandleLidSwitchDocked = lib.mkDefault "ignore";
}
