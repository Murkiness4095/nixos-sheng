# flake-parts personal configuration

English · [简体中文](./README.md)

This English overview links to the [full Chinese reference](./README.md) for commands and evidence.

The default root partition is `userdata`. For dual boot, set `sheng.rootfs.partlabel = "linux";` in `node-sheng` or extend `inputs.nixos-sheng.nixosConfigurations.sheng-dual`. Use the supplied lock file, stage new flake files before building, and keep x86-only settings out of the tablet configuration. The optional persistence example is a NixOS module.

[Optional tmpfs root](../../docs/initrd-tmpfs.en.md)
