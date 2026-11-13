# Android and NixOS dual boot

English · [简体中文](./dual-boot.md)

This English overview links to the [full Chinese reference](./dual-boot.md) for commands and evidence.

The tested layout uses Android A and NixOS B. NixOS mounts the separate `linux` partition. The stock single-system scripts can write both boot slots or erase `userdata`; follow the original guide for partitioning and flashing commands. Routine NixOS updates use `nixos-rebuild boot` and the generation menu. Android maintenance uses selective reflashing.

[Maintainer handover](HANDOVER.en.md)
