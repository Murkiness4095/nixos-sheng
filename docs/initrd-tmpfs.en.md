# Optional initrd and tmpfs root

English · [简体中文](./initrd-tmpfs.md)

This English overview links to the [full Chinese reference](./initrd-tmpfs.md) for commands and evidence.

Images default to an ext4 root. Initrd and tmpfs root are opt-in. With tmpfs, retain the correct backing partition label and explicitly configure persistence. The example preserves selected directories for a caller-supplied user. Full home persistence is opt-in. Keep the previous ext4 generation available for rollback.

[Persistence example](../examples/tmpfs-root.nix)

For EFI, use the optional `sheng-efi-tmpfs` (single-system) and
`sheng-dual-efi-tmpfs` (dual-system) build targets as references. They pair the
existing tmpfs module with systemd-boot and mount `sheng-esp` at `/efi`.
On an existing EFI install, enable `sheng.rootfs.tmpfsRoot.enable` in your own
host configuration, retain your persistence settings, and run
`nixos-rebuild boot`. After reboot, verify the mounts at `/`, `/nix`,
`/persist`, and `/efi`, and check that your selected data persisted.
Select the previous ext4 generation in systemd-boot to roll back.
