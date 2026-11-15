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

## Persist U-Boot in the boot slot

The EFI files are stored on the ESP. A normal reboot uses the U-Boot image
installed in the boot slot. Use the same image that passed temporary boot.

- Dual boot was tested with the dual-system image written only to `boot_b`.
- For a single system, use the single-system image. The slot B steps below
  apply after verifying temporary boot from B with `userdata` as the root
  partition. Persistent slot B boot, generation updates, rollback and cold
  boot were tested on the existing `userdata`. A single system can use either slot.

Verify the original `boot_b` backup is recoverable. In ABL fastboot, check
that you have the right device and that `fastboot getvar current-slot` reports
`b` before writing.

```sh
fastboot flash boot_b boot.img
fastboot reboot
```

After normal boot, check `bootctl status` and `findmnt /efi`. To revert,
restore the original image to the same `boot_b` from ABL fastboot.

## Fresh installation: boot directly into EFI

Run **EFI experiments** with `task=install-bundle` and select `layout=single`
or `layout=dual`. Download `boot.img`, `sheng-rootfs.sparse.img.zst`, and
`sheng-esp.sparse.img` from the same artifact. Run `sha256sum -c SHA256SUMS`,
then check the layout and root partition label in `manifest.txt`. ARM CI
built both bundles. Direct first boot from the complete bundle has not been
tested on hardware. For the tested path, install extlinux and migrate as above.

1. Reserve a separate EFI System Partition of at least 512 MiB with GPT
   partition label `sheng-esp`. For single system, leave room outside
   `userdata` before first boot grows the root filesystem. For dual boot,
   follow the [dual-boot guide](dual-boot.en.md), preserve Android slot A and
   Recovery, and leave space outside `linux`. Use the target device's GPT
   when calculating partition boundaries.
2. Decompress the Zstandard wrapper and write the Android sparse root image
   to the root partition named in the manifest. Write the separate ESP image
   only to `sheng-esp`; it replaces any existing ESP contents. If ABL does
   not expose the ESP, use Recovery, convert the sparse image to raw with
   `simg2img`, and verify the partition by GPT label before writing. Do not
   pass the sparse image directly to `dd`.
3. In ABL, temporarily boot the bundled `boot.img`. Verify the root partition
   and `/efi` mount. Check `journalctl -b -u sheng-finish-efi-install` and
   `bootctl list`: a regular NixOS generation should replace the seed entry.
   Install an update with `nixos-rebuild boot --flake /etc/nixos` and verify
   it boots before deploying U-Boot to the Linux boot slot identified above.

Use a known-good generation or temporary ABL boot for recovery. If the
internal EFI fallback file is missing, U-Boot tries the root image's
extlinux rescue entry. Restoring the boot image alone does not require
erasing the root filesystem.
