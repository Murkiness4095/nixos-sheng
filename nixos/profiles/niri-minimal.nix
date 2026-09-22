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
  # --session imports environment into systemd/D-Bus and is required for
  # Noctalia and other systemd user services to integrate properly.
  niriCommand = "${lib.getExe pkgs.niri} --session";
  tuigreetCommand = "${lib.getExe pkgs.tuigreet}";

  # niri resolves its configuration as $XDG_CONFIG_HOME/niri/config.kdl,
  # falling back to /etc/niri/config.kdl, and only uses the default config
  # embedded in the binary when neither exists. Almost every section is filled
  # in from defaults when omitted, but the key bindings are explicitly not, so
  # shipping a minimal file here silently disabled every default binding.
  # Include niri's own default config and only add Noctalia as the shell.
  #
  # Note: the included default config also starts waybar (upstream default).
  # waybar is not installed in this image, so that one spawn fails harmlessly.
  niriConfig = ''
    include "${pkgs.niri.doc}/share/doc/niri/default-config.kdl"

    // sheng: Noctalia is the shell for this image.
    spawn-at-startup "noctalia"
  '';
in
{
  # Niri compositor from nixpkgs.
  programs.niri.enable = true;

  # Niri configuration: upstream default config (including all default key
  # bindings) with Noctalia started at login instead of waybar.
  environment.etc."niri/config.kdl".text = niriConfig;

  # System language for this desktop image. configuration.nix keeps
  # en_US.UTF-8 as its default, so override it here; the CJK fonts needed for
  # Chinese rendering are installed further below.
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # Graphics stack.
  hardware.graphics.enable = true;

  # Noctalia prerequisites. NetworkManager is already enabled in configuration.nix;
  # the remaining services are enabled here for profile completeness.
  hardware.bluetooth.enable = lib.mkDefault true;
  services.upower.enable = lib.mkDefault true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # Default applications requested for the image.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-volman
      thunar-archive-plugin
    ];
  };

  # Thumbnail service and GVFS for Thunar file previews and removable media.
  services.tumbler.enable = true;
  services.gvfs.enable = true;

  # Graphical polkit agent (used by Thunar "open as administrator" etc.)
  security.soteria.enable = true;

  # Fonts used by the downstream sheng dotfiles configuration.
  fonts.packages = with pkgs; [
    cantarell-fonts
    inter
    maple-mono.NF
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    alacritty
    kitty
    fuzzel
    thunar

    # Browsers
    brave
    firefox

    # Chat
    # (telegram-desktop removed: it pulls kdePackages.kcoreaddons, whose Python
    #  bindings drag in pyside6 and the entire Qt6 module tree, including
    #  qt3d/qtspeech which have no aarch64 binary cache)
    # qq temporarily disabled: upstream deb 404 in nixpkgs
    wechat

    # Media
    kazumi
    celluloid # video
    imv # image
    ffmpegthumbnailer
    ffmpeg ffmpeg-full ffmpeg-headless
    ffmpeg_4 ffmpeg_6 ffmpeg_7 ffmpeg_8
    poppler
    poppler-utils
    libopenraw
    libgsf
    imagemagick
    go-musicfox

    # Editor / KDE integration
    # (kate and plasma-integration removed: depend on qtspeech which has no aarch64 cache)

    # Tools
    localsend
    brightnessctl # Backlight control for Noctalia OSD and hardware keys
    fastfetch
    microfetch
    just
    gh
    btop
    wlr-randr
    tree
    nh
    nix-output-monitor
    nvd
    nix-tree
    nil
    nixfmt
    nixpkgs-fmt
    file
    fd
    ripgrep
    fzf
    tmux
    yazi

    # Input method packages (fcitx5 configuration is left to the user)
    fcitx5-fluent
    fcitx5-material-color
    fcitx5-rime
    libsForQt5.fcitx5-qt
    fcitx5-gtk

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
    adw-gtk3
    adwaita-icon-theme
    hicolor-icon-theme
    papirus-icon-theme
    kdePackages.breeze-icons
    gnome-themes-extra

    # Niri ecosystem
    kanshi
    wpaperd
    swaylock-effects
    swayidle
    wlogout
    uwsm

    # Vibe Coding
    mcp-nixos

    # Basic utilities from the downstream system config
    git
    vim
    wget
    curl
    htop

    # XWayland support for legacy X11 apps under Niri
    xwayland-satellite
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
  # We start it via Niri's spawn-at-startup instead of the systemd user service,
  # because the greetd-based session does not reliably reach graphical-session.target
  # before Niri has created the Wayland socket.
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
    systemd.enable = false;
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
