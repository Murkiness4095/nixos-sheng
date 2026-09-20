# ---
# Module: User Profile
# Description: Hjem-managed files and packages for the dynamic user
# Scope: Hjem User
# ---

{ pkgs, vars, ... }:

{
  packages = with pkgs; [
    gjs-osk
    gnome-console
    nautilus
    curl
    evtest
    gitMinimal
    brightnessctl
    iproute2
    iw
    nano
    pciutils
    usbutils
    vim
    wget
  ];

  files.".bashrc".text = ''
    # Source the NixOS system-wide bashrc before adding user aliases.
    if [ -f /etc/bashrc ]; then
      . /etc/bashrc
    fi

    alias nrs="sudo sheng-nixos-rebuild /home/${vars.username}/nixos-sheng/nixos#sheng-stage2"
  '';
}
