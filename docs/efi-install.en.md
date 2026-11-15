# EFI installation and migration

English · [简体中文](efi-install.md)

EFI is optional. U-Boot loads systemd-boot from an internal FAT32 EFI System
Partition (ESP) with the GPT partition label `sheng-esp`.

| Layout | Root partition label | EFI configuration reference | U-Boot artifact |
| --- | --- | --- | --- |
| Single system | `userdata` | `sheng-efi-generations` | `sheng-efi-internal-single` |
| Dual boot | `linux` | `sheng-dual-efi-generations` | `sheng-efi-internal-dual` |

Run **EFI experiments** in GitHub Actions with `task=internal-esp`. Download
`boot.img` from the matching artifact and verify its SHA-256 against the build log.
See the [hardware validation records](efi-probe.md) for tested revisions.

## Migrate an extlinux installation

Flashing U-Boot alone cannot install systemd-boot or write entries for your
NixOS generations. Prepare the ESP and install a generation before deploying
the EFI U-Boot image.

1. Check the current slot and root partition. Back up the boot image and any
   existing ESP. Keep a bootable extlinux generation and its DTB under
   `/boot`. The tested dual-boot layout uses Android A and Linux B.
2. Prepare an independent GPT EFI System partition, labeled `sheng-esp` and
   formatted as FAT32. The test used 512 MiB. Size it for the generations you
   plan to keep and leave room for updates. If an existing ext4 filesystem
   must shrink, back it up and verify recovery, then shrink it offline before
   shortening its GPT partition.
3. Apply the settings from the matching EFI configuration to your own host
   configuration. Keep your existing users, desktop and storage settings.
   The reference enables initrd, the EFI stub, systemd-boot DTB installation,
   the mixed-generation patch and automatic ESP mounting. From extlinux, run:

   ```sh
   sudo nix run .#sheng-efi-migrate
   ```

   Append your usual flake and host as `-- --flake <path>#<host>` if applicable. This command mounts
   the ESP for the first install. A missing partition or failed mount stops
   the command. The migration tool rejects an already-mounted wrong partition
   before writing.
4. Enter ABL fastboot and verify the device and slot. Temporarily load the
   matching image with `fastboot boot boot.img`. Check `bootctl status`,
   `findmnt /`, `findmnt /efi` and `readlink -f /run/booted-system`. The EFI
   system mounts `/efi` automatically. Verify an update with
   `nixos-rebuild boot` and a rollback with `sudo nixos-rebuild boot --rollback`,
   rebooting after each. Reload the candidate at each temporary boot.
5. Persistent dual-boot deployment was tested by writing only `boot_b` after
   temporary boot passed and the original `boot_b` backup was verified. The
   single-system candidate was tested using temporary boot.

## Fresh installation

The current root images are extlinux base images. Flashing one alongside the
EFI U-Boot image does not create the GPT partition or populate the ESP.

1. Reserve the ESP before first-boot root filesystem growth. Use `userdata`
   for single-system installs. The end-of-disk ESP layout was checked offline.
   Calculate boundaries from the target device's GPT. For dual boot, reserve
   ESP space alongside `linux` and follow the [dual-boot guide](dual-boot.en.md).
2. Build the root image using **build** (single) or **build-dual** (dual).
   Follow the matching [single-system flashing steps](README.md#flashing)
   or [dual-boot guide](dual-boot.en.md). Boot extlinux once and check the root
   partition and filesystem growth.
3. Start at step 3 of migration to install the EFI generation. Keep the
   initial extlinux generation for recovery.

The migration tool automates the first mount and EFI entry installation
once the ESP exists. Direct EFI installation would also need to prepare the
ESP and write its boot files. The existing flash scripts do not perform those
steps.

For a broken EFI generation, select an earlier one in systemd-boot. When the
EFI fallback file is missing, the candidate tries extlinux. To undo the tested
persistent dual-boot deployment, enter ABL, verify slot B and restore the
original `boot_b`.
