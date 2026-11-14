# Maintainer handover

English · [简体中文](./HANDOVER.md)

This English overview links to the [full Chinese reference](./HANDOVER.md) for commands and evidence.

The verified layout boots NixOS from the `linux` partition in slot B, with Android in slot A. Verify the live slot, partition label, hostname and system path before changing the device. Use native ARM CI, verify artifact checksums, and keep a bootable generation for rollback. A normal NixOS update uses the generation workflow.

Temporary systemd-boot probes have booted on both layouts. Generation update and rollback passed in a NixOS VM. Persistent installation on sheng remains open. [EFI test results](efi-probe.md)

[Dual boot](dual-boot.en.md) · [Hardware validation](peripheral-validation.en.md)
