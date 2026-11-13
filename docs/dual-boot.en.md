# Android and NixOS dual boot

English · [简体中文](dual-boot.md)

The tested layout boots Android from slot A and NixOS from slot B. NixOS uses a separate GPT partition labeled `linux`. Select the OS through ABL fastboot. [Debian-sheng reference](https://github.com/ianchb/debian-sheng#flashing-to-your-device)

| Item | Single system | Dual system |
| --- | --- | --- |
| Flake configuration | `sheng` | `sheng-dual` |
| Rootfs build | `nix build .#nixos` | `nix build .#nixos-dual` |
| U-Boot build | `nix build .#u-boot` | `nix build .#u-boot-dual` |
| Root partition | `userdata` | `linux` |
| CI workflow | `build` | `build-dual` |

Both modes share the kernel, DTB, firmware and services. The dual-system U-Boot reads its menu, normal boot files and rescue files from `linux`. The `sheng-dual-flashable` artifact contains `sheng-boot-dual.img` and `sheng-rootfs-dual.sparse.img.zst`.

## Update an existing installation

For the stock dual-system configuration in `/etc/nixos`, add a generation and reboot.

```sh
sudo nixos-rebuild boot --flake /etc/nixos#sheng-dual
sudo reboot
```

A personal configuration using `lib.shengSystem` must set `sheng.rootfs.partlabel = "linux";`. Extending `nixosConfigurations.sheng-dual` inherits that partition setting and the hostname `sheng-dual`. Use your own flake output when rebuilding a personal configuration. With tmpfs root, `linux` still identifies the persistent backing partition. Keep a known-good generation in the U-Boot menu. [Minimal example](../examples/minimal/README.en.md) · [flake-parts example](../examples/flake-parts/README.en.md)

## Install with Android A already working

When migrating from a working single-system installation, preserve `userdata` while testing the separate `linux` system with a temporary boot. Restore Android only after verifying the new Linux installation.

The commands below assume Android A already boots and the existing `linux` partition may be overwritten. Confirm the target with `fastboot devices` and check the slot layout before proceeding. Use the dual-system artifacts. The single-system scripts target both boot slots or `userdata`.

```sh
zstd -d sheng-rootfs-dual.sparse.img.zst
fastboot erase dtbo_b
fastboot flash boot_b sheng-boot-dual.img
fastboot erase linux
fastboot flash linux sheng-rootfs-dual.sparse.img
fastboot set_active b
fastboot reboot
```

Erasing `linux` clears old data that Android sparse image DONT_CARE regions may otherwise leave behind. Preserve `userdata`, `metadata` and Android A partitions.

## Switch operating systems

From NixOS, enter ABL fastboot with `sudo systemctl reboot --reboot-argument=bootloader`. On the host, run `fastboot set_active a` followed by `fastboot reboot` to boot Android. From Android, enter fastboot again and use `fastboot set_active b` followed by `fastboot reboot` to return to NixOS. `fastboot reboot recovery` starts recovery for the active slot.

## Restore only the Linux boot entry

If Android A already works and only the Linux boot entry needs restoring, use a matching dual-system U-Boot image.

```sh
fastboot flash boot_b sheng-boot-dual.img
fastboot erase dtbo_b
fastboot set_active b
fastboot reboot
```

Preserve the GPT, `linux`, `userdata` and `metadata` during boot-entry recovery. Review Android ROM scripts before running them. An Android OTA can overwrite B-slot boot files and change the active slot. Confirm Android A is bootable before restoring Linux B. Automatic OTA preservation is outside the project scope.

## Tested scope

The project verified booting the CI image from `linux`, generation updates and rollback, and switching both ways with Android 16 `OS3.0.304.0.WNXCNXM`. The test preserved the original `super` and restored matching official boot-chain images. See the hardware record for peripheral coverage and the Chinese guide for the detailed migration record. [Hardware validation](peripheral-validation.en.md) · [Migration record](dual-boot.md)
