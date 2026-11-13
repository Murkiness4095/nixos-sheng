# Maintainer handover

English · [简体中文](./HANDOVER.md)

This English overview links to the [full Chinese reference](./HANDOVER.md) for commands and evidence.

The verified layout boots NixOS from the `linux` partition in slot B, with Android in slot A. Verify the live slot, partition label, hostname and system path before changing the device. Use native ARM CI, verify artifact checksums, and keep a bootable generation for rollback. A normal NixOS update uses the generation workflow.

[Dual boot](dual-boot.en.md) · [Hardware validation](peripheral-validation.en.md)
