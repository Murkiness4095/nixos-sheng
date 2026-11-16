# flake-parts personal configuration

English · [简体中文](./README.md)

This English overview links to the [full Chinese reference](./README.md) for commands and evidence.


[Optional tmpfs root](../../docs/initrd-tmpfs.en.md)

## Select the target for your installation

| Root partition | EFI bundle | Regular extlinux image |
| --- | --- | --- |
| Single system, `userdata` | `.#sheng` (default template target) | `.#sheng-extlinux` |
| Dual boot, `linux` | `.#sheng-dual-efi` | `.#sheng-dual-extlinux` |

For an existing extlinux setup, use the matching extlinux target for routine updates.
Example: `sudo nixos-rebuild boot --flake .#sheng-dual-extlinux` updates an existing dual-boot extlinux install.
 To move to EFI, prepare the ESP and U-Boot as described below.

## EFI boot

The EFI targets use systemd-boot. Select the default `.#sheng`
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
single-system installation, use `sheng` in both commands.
