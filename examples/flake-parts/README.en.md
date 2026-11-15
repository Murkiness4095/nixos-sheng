# flake-parts personal configuration

English · [简体中文](./README.md)

This English overview links to the [full Chinese reference](./README.md) for commands and evidence.

The default root partition is `userdata`. For dual boot, set `sheng.rootfs.partlabel = "linux";` in `node-sheng` or extend `inputs.nixos-sheng.nixosConfigurations.sheng-dual`. Use the supplied lock file, stage new flake files before building, and keep x86-only settings out of the tablet configuration. The optional persistence example is a NixOS module.

[Optional tmpfs root](../../docs/initrd-tmpfs.en.md)

## Optional EFI boot

The default `.#sheng` target uses extlinux. For EFI, select `.#sheng-efi`
for single-system installations on `userdata`, or `.#sheng-dual-efi` for
dual boot on `linux`. Leave the root partition label to the selected target.
The hostname remains `sheng`, so pass the target explicitly when rebuilding.

Follow the [EFI installation and migration guide](../../docs/efi-install.en.md)
to prepare `sheng-esp` and the matching U-Boot image. For the first migration
on dual boot, install the candidate with:

```sh
sudo nix run github:Murkiness4095/nixos-sheng#sheng-efi-migrate -- --flake "$PWD#sheng-dual-efi"
```

Once the EFI generation boots and mounts `/efi` automatically, run
`sudo nixos-rebuild boot --flake .#sheng-dual-efi` for updates. For a
single-system installation, use `sheng-efi` in both commands.
