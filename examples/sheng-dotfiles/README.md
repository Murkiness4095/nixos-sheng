# Sheng dotfiles template

Copy this directory into a private repository, replace the example user and
password, then initialize its lock file:

```sh
nix flake lock
sudo nixos-rebuild build --flake .#sheng
sudo nixos-rebuild switch --flake .#sheng
```

Update the hardware platform independently with:

```sh
nix flake update nixos-sheng
sudo nixos-rebuild build --flake .#sheng
```

The `nixos-sheng` input owns the Mobile NixOS device platform. This private
flake owns users, credentials, personal packages, and Hjem settings.
`mkShengSystem` does not select a desktop environment. Replace it with
`mkShengGnomeSystem` when the repository GNOME profile is desired, or with
`mkShengNiriSystem` for the Niri + Noctalia profile.
