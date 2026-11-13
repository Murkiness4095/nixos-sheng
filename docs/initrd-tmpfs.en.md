# Optional initrd and tmpfs root

English · [简体中文](./initrd-tmpfs.md)

This English overview links to the [full Chinese reference](./initrd-tmpfs.md) for commands and evidence.

Images default to an ext4 root. Initrd and tmpfs root are opt-in. With tmpfs, retain the correct backing partition label and explicitly configure persistence. The example preserves selected directories for a caller-supplied user. Full home persistence is opt-in. Keep the previous ext4 generation available for rollback.

[Persistence example](../examples/tmpfs-root.nix)
