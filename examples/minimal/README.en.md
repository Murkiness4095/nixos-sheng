# Minimal personal configuration

English · [简体中文](./README.md)

This English overview links to the [full Chinese reference](./README.md) for commands and evidence.

The default root partition is `userdata`. For dual boot, set `sheng.rootfs.partlabel = "linux";` or extend the repository’s `sheng-dual` configuration. Keep the supplied lock file for the initial build. Run `sudo nixos-rebuild build --flake .#sheng` before installing the generation with `sudo nixos-rebuild boot --flake .#sheng`. Keep a working generation.

[Optional tmpfs root](../../docs/initrd-tmpfs.en.md)
