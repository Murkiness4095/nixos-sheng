# nixos-sheng

English · [简体中文](./README.md)

Standard NixOS with U-Boot for the Xiaomi Pad 6S Pro (sheng). Hardware integration follows [Debian-sheng](https://github.com/ianchb/debian-sheng). The current kernel is Linux 7.3.4, boot-tested with NixOS 26.11. The tested dual-system layout uses Android in slot A with `userdata` and NixOS in slot B with `linux`.

[English documentation index](docs/index.en.md) · [Sponsor](docs/sponsor.en.md)

The project has verified boot, standard NixOS rebuilds, generation rollback, switching between Android and NixOS, and specific peripheral interactions. Desktop behavior and long-term standby still need validation. See the hardware records for the scope of each test.

| Task | Start here |
| --- | --- |
| Build or install the single-system image | [Project guide](docs/README.md) |
| Install or maintain Android alongside NixOS | [Dual boot](docs/dual-boot.en.md) |
| Configure initrd or a tmpfs root | [Initrd and persistence](docs/initrd-tmpfs.en.md) |
| Maintain the project or troubleshoot boot | [Handover](docs/HANDOVER.en.md), [development guide](docs/DEVELOPMENT.md) |
| Check hardware coverage or choose the next task | [Hardware validation](docs/peripheral-validation.en.md), [roadmap](TODO.en.md) |

GitHub Actions runs `build` for single-system configurations and `build-dual` for dual-system configurations. Pushes and pull requests run checks and export update closures. To build an installation image, run the matching workflow manually and select `tty`, `kde`, or `gnome` in the `image` field. The default `none` exports update closures only. Installed systems can use `nixos-rebuild boot` to add a generation.
For a `tty` image, set `tty_username` to create and automatically log in as a regular user. The default is `root`.

Confirm the installation mode before flashing. The `fastboot-flash` and `flash-uboot` scripts write both boot slots. `flash-rootfs` overwrites `userdata`. Follow the dual-boot guide when preserving Android.

## Sponsor

[View sponsorship details](docs/sponsor.en.md)
