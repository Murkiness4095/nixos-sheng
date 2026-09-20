# ---
# Module: Personal User Home
# Description: Provides an example Hjem profile for the private sheng user
# Scope: Hjem User
# ---

{ ... }:

{
  files.".bashrc".text = ''
    # Source the NixOS system-wide bashrc before adding user aliases.
    if [ -f /etc/bashrc ]; then
      . /etc/bashrc
    fi

    alias ll="ls -la"
  '';
}
