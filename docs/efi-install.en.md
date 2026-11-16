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
The stock GPT has no `sheng-esp`. The migration tool mounts and verifies an existing ESP, then runs `nixos-rebuild boot`. Partition creation, formatting, and U-Boot flashing are separate steps. If EFI-capable U-Boot is already installed in the active Linux boot slot and you have a working ESP, start at step 3. This includes older generations launched from the EFI menu that still install updates through extlinux. After step 3, reboot normally and verify the new generation and ESP mount. Skip temporary boot and persistent flashing in this case.


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
   shortening its GPT partition. Follow [the ext4 preservation procedure](#make-room-while-preserving-ext4-data).
   If there is enough free space, use the free-space path under [Create the ESP](#create-sheng-esp-on-the-tablet). The fresh-install shrink procedure assumes that rootfs will be overwritten. Format only a verified, unmounted, newly created empty ESP. Keep the contents of an existing FAT32 ESP.

   ```sh
   sudo mkfs.fat -F 32 -S 4096 -s 1 /dev/disk/by-partlabel/sheng-esp
   ```
3. Apply the settings from the matching EFI configuration to your own host
   configuration. Keep your existing users, desktop and storage settings.
   The reference enables initrd, the EFI stub, systemd-boot DTB installation,
   the mixed-generation patch and automatic ESP mounting. From extlinux, run:

   ```sh
   sudo nix run github:Murkiness4095/nixos-sheng#sheng-efi-migrate
   ```

   Append your usual flake and host as `-- --flake <path>#<host>` if applicable. This command mounts
   the ESP for the first install. A missing partition or failed mount stops
   the command. The migration tool rejects an already-mounted wrong partition
   before writing.
4. Enter ABL fastboot and verify the device and slot. Temporarily load the
   matching image with `fastboot boot boot.img`. Check `bootctl status`,
   `findmnt /`, `findmnt --mountpoint /efi` and `readlink -f /run/booted-system`. The EFI
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

After normal boot, check `bootctl status` and `findmnt --mountpoint /efi`. To revert,
restore the original image to the same `boot_b` from ABL fastboot.

### Make room while preserving ext4 data

Use this procedure only for an offline, shrinkable ext4 filesystem in the
last partition of its GPT. For single system, it must be NixOS `userdata`.
For dual boot, it must be `linux`. Stop if the filesystem is Android F2FS,
an encrypted volume, another filesystem type, or outside the last partition.
Back up the data separately and verify that it can be restored. Run each
block separately and stop on errors.

Run as root in an offline Linux rescue environment on the tablet. Use a
version of `e2fsck`, `tune2fs`, and `resize2fs` that supports the filesystem's
features, plus the GPT tools listed below. The project tested e2fsprogs 1.47.4.
Older recovery tools may lack support for those features.

```sh
# Set these from the verified device and layout.
disk=/dev/REPLACE_ME
root_num=REPLACE_ME
root_label=REPLACE_ME  # userdata (single) or linux (dual)
esp_mib=REPLACE_ME     # 512 or 1024
case "$root_label" in userdata|linux) ;; *) exit 1 ;; esac
case "$esp_mib" in 512|1024) ;; *) exit 1 ;; esac

root=$(readlink -f "/dev/disk/by-partlabel/$root_label")
test -b "$disk" && test -b "$root" || exit 1
test "$(lsblk -dnro PKNAME "$root")" = "${disk##*/}" || exit 1
test "$(lsblk -dnro PARTN "$root")" = "$root_num" || exit 1
test "$(lsblk -dnro FSTYPE "$root")" = ext4 || exit 1
test -z "$(lsblk -dnro MOUNTPOINTS "$root")" || exit 1

LC_ALL=C sgdisk --print "$disk"
LC_ALL=C sgdisk --info="$root_num" "$disk"
```

```sh
# Run only after confirming root_num is the last partition by sector.
# Keep the GPT backup on a separate device before continuing.
sgdisk --backup=/tmp/sheng-gpt-before.bin "$disk"
```

```sh
# Use the first and last sectors reported by sgdisk --info.
root_start=REPLACE_ME
root_end=REPLACE_ME
sector_bytes=$(blockdev --getss "$disk")
align=$((1048576 / sector_bytes))
esp_sectors=$((esp_mib * 1048576 / sector_bytes))
esp_start=$(( (root_end + 1 - esp_sectors) / align * align ))
new_root_end=$((esp_start - 1))
new_bytes=$(( (new_root_end - root_start + 1) * sector_bytes ))
test "$new_bytes" -gt 1048576 || exit 1

e2fsck -fn "$root" || exit 1
fs_info=$(LC_ALL=C tune2fs -l "$root") || exit 1
fs_block_size=$(printf '%s\n' "$fs_info" | awk '/^Block size:/ {print $3}')
fs_blocks=$(printf '%s\n' "$fs_info" | awk '/^Block count:/ {print $3}')
test "${fs_block_size:-0}" -gt 0 && test "${fs_blocks:-0}" -gt 0 || exit 1
target_blocks=$(( (new_bytes - 1048576) / fs_block_size ))
test "$target_blocks" -gt 0 || exit 1

if [ "$fs_blocks" -gt "$target_blocks" ]; then
  resize2fs "$root" "$target_blocks" || exit 1
fi
e2fsck -fn "$root" || exit 1
fs_info=$(LC_ALL=C tune2fs -l "$root") || exit 1
fs_blocks=$(printf '%s\n' "$fs_info" | awk '/^Block count:/ {print $3}')
test "${fs_blocks:-0}" -gt 0 || exit 1
test "$((fs_blocks * fs_block_size))" -lt "$new_bytes" || exit 1
printf 'New root end: %s, filesystem bytes: %s, partition bytes: %s\n' \
  "$new_root_end" "$((fs_blocks * fs_block_size))" "$new_bytes"
```

```sh
parted "$disk" unit s resizepart "$root_num" "${new_root_end}s"
sgdisk --verify "$disk"
sgdisk --info="$root_num" "$disk"
partprobe "$disk"
```

Run the final GPT change only after the filesystem checks have passed.
Confirm Parted shows the intended partition. Verify the start and PARTUUID
are unchanged and the end is `new_root_end`. Then use the free-space commands
under [Create the ESP](#create-sheng-esp-on-the-tablet). Return to migration
step 2, format only the new empty ESP, and install the EFI generation.
Migration does not require flashing rootfs.

## Fresh installation: boot directly into EFI

**The stock GPT has no `sheng-esp` partition. Create it before flashing.**
The bundle supplies the contents of the ESP. Flashing an image does not create
a GPT partition. If the existing GPT has too little unallocated space, back up
your data and make room according to the device's layout. Verify that
`sheng-esp` exists and is large enough before flashing.

```text
Inspect GPT → create and verify sheng-esp → decompress rootfs
  → flash rootfs → flash ESP → temporarily boot boot.img
  → verify systemd-boot and the regular generation → flash the boot slot
```

| Bundle file | Destination |
| --- | --- |
| `sheng-rootfs.sparse.img.zst` | Run `zstd -d sheng-rootfs.sparse.img.zst` on the host. Flash the resulting `sheng-rootfs.sparse.img` to `userdata` for single system or `linux` for dual boot. |
| `sheng-esp.sparse.img` | Write only to the ESP you created as `sheng-esp`. If ABL does not expose it, use Recovery as described below. |
| `boot.img` | Run `fastboot boot boot.img` in ABL first. After validation, flash the verified Linux boot slot. The tested dual-boot layout uses only `boot_b`. |

**Choose the bundle size to match the actual partition.** The test tablet
has a **512 MiB** ESP. The workflow defaults to a **1024 MiB (1 GiB)** ESP
image, which does not fit that partition. Set `esp_size_mib=512` to reuse
an existing 512 MiB ESP, or reserve at least 1 GiB for the default bundle.
Check `esp_size_mib` in `manifest.txt`. In-place migration writes boot files
and can reuse an existing ESP with enough free space without flashing an image.

Run **EFI experiments** with `task=install-bundle` and select `layout=single`
or `layout=dual`. Set `esp_size_mib` to 512 or 1024, with 1024 as the default. Download `boot.img`, `sheng-rootfs.sparse.img.zst`, and
`sheng-esp.sparse.img` from the same artifact. Run `sha256sum -c SHA256SUMS`,
then check the layout and root partition label in `manifest.txt`. ARM CI
built both bundles. Direct first boot on a full single-system layout has not been
tested on hardware. For the tested path, install extlinux and migrate as above.

1. Use the commands under “Create `sheng-esp` on the tablet” below. Reserve a separate EFI System Partition at least as large as the ESP image with GPT
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
   Install an update with `sudo nixos-rebuild boot --flake /etc/nixos#<configuration>`, using the `configuration` value in the bundle manifest, and verify
   it boots before deploying U-Boot to the Linux boot slot identified above.

### Commands for writing the images

On your computer, verify the bundle and decompress the rootfs. Confirm
`fastboot devices` lists only the tablet. Run **only the rootfs command for
your layout**, and run the ESP flash command only if the bootloader exposes
the partition and reports sufficient capacity.

```sh
sha256sum -c SHA256SUMS
zstd -d sheng-rootfs.sparse.img.zst
fastboot devices
```

Single system only:

```sh
fastboot flash userdata sheng-rootfs.sparse.img
```

Dual boot only:

```sh
fastboot flash linux sheng-rootfs.sparse.img
```

ESP only when exposed by fastboot:

```sh
fastboot getvar partition-size:sheng-esp
fastboot flash sheng-esp sheng-esp.sparse.img
```

If fastboot cannot access the target partition, use an offline Linux
rescue environment that can identify it by GPT label. Convert the applicable
sparse image to raw on the computer first. For example, for the ESP:

```sh
simg2img sheng-esp.sparse.img sheng-esp.raw.img
```

Copy the raw image to the rescue environment using external storage or ADB
where available. Run the block write **on the tablet**, after verifying the
target is the unmounted ESP and the raw file fits. Never write to the parent disk.

```sh
lsblk -b -o PATH,TYPE,SIZE,PARTLABEL,PARTTYPE,MOUNTPOINTS
esp=/dev/disk/by-partlabel/sheng-esp
image=/path/to/sheng-esp.raw.img
test -b "$esp" && test -f "$image" || exit 1
test "$(lsblk -dnro PARTTYPE "$esp")" = c12a7328-f81f-11d2-ba4b-00a0c93ec93b || exit 1
test "$(lsblk -dnro PARTLABEL "$esp")" = sheng-esp || exit 1
test -z "$(lsblk -dnro MOUNTPOINTS "$esp")" || exit 1
test "$(stat -c %s "$image")" -le "$(blockdev --getsize64 "$esp")" || exit 1
dd if="$image" of="$esp" bs=4M conv=fsync
```

### Create `sheng-esp` on the tablet

Run these commands as root in an offline Linux rescue environment on the
tablet with `lsblk`, `blockdev`, `sgdisk` (GPT fdisk), `parted`, and `partprobe`.
Use Recovery only if it provides those tools. Unmount the target UFS
partitions first. Do not run these commands against a disk on your PC.

```sh
lsblk -o PATH,TYPE,SIZE,PKNAME,PARTLABEL,PARTUUID,MOUNTPOINTS
```

Identify the parent disk of `userdata` for single system or of the existing
`linux` partition for dual boot. If `linux` has yet to be created, prepare
the dual-boot layout first and reserve room for the ESP. Replace
`/dev/REPLACE_ME` with the verified **parent disk**, then copy the GPT
backup to your PC or external storage. It contains only the partition table.

```sh
disk=/dev/REPLACE_ME
test -b "$disk" || exit 1
sgdisk --backup=/tmp/sheng-gpt-before.bin "$disk"
sgdisk --print "$disk"
parted -s "$disk" unit s print free
```

**If there is enough contiguous free space**, skip to the creation command
below. **If there is no room**, the following procedure applies only to the
last partition on that GPT when it will be overwritten by the fresh install:
`userdata` for single system, or `linux` for dual boot. Confirm it is unmounted
and its data can be discarded. On dual boot, leave Android's `userdata` alone.
To preserve an existing ext4 filesystem, shrink it offline and verify that
it fits the new boundary before shrinking the partition. Follow the migration
path instead of using this fresh-install procedure.

```sh
# Replace both placeholders with integers from sgdisk --print on your device.
root_num=REPLACE_ME
root_end=REPLACE_ME
esp_mib=REPLACE_ME  # 512 or 1024, matching manifest.txt
sector_bytes=$(blockdev --getss "$disk")
align=$((1048576 / sector_bytes))
esp_sectors=$((esp_mib * 1048576 / sector_bytes))
esp_start=$(( (root_end + 1 - esp_sectors) / align * align ))
new_root_end=$((esp_start - 1))
printf 'New root end: %s, ESP start: %s\n' "$new_root_end" "$esp_start"
```

Check that the new end is after the start and that the resulting partition
can hold the **expanded raw rootfs**. Run
`parted "$disk" unit s resizepart "$root_num" "${new_root_end}s"` and confirm the
shrink only if it shows the intended partition and boundary. This changes
the GPT boundary. Flashing rootfs later replaces the original filesystem.
If Parted reports an error, stop and inspect the table.

```sh
# Also start here if the disk already has free space. Match the bundle size.
esp_mib=REPLACE_ME  # 512 or 1024, matching manifest.txt
sector_bytes=$(blockdev --getss "$disk")
align=$((1048576 / sector_bytes))
if lsblk -nr -o PARTLABEL "$disk" | grep -Fxq sheng-esp; then exit 1; fi
start=$(sgdisk --set-alignment="$align" --first-aligned-in-largest "$disk")
free_end=$(sgdisk --end-of-largest "$disk")
end=$((start + esp_mib * 1048576 / sector_bytes - 1))
test "$start" -gt 0 && test "$end" -le "$free_end" || exit 1

# Preview and check the name and boundaries of the one new partition.
sgdisk --pretend --set-alignment="$align" --new="0:$start:$end" \
  --typecode=0:EF00 --change-name=0:sheng-esp --print "$disk"
# After checking, run without --pretend to save the new table.
sgdisk --set-alignment="$align" --new="0:$start:$end" \
  --typecode=0:EF00 --change-name=0:sheng-esp "$disk"
sgdisk --verify "$disk"
partprobe "$disk"
lsblk -b -o PATH,SIZE,PARTLABEL,PARTTYPE "$disk"
```

If the kernel cannot reread the table, reboot into the rescue environment
and check again. Verify there is exactly one `sheng-esp`, at least as large
as the ESP image, with type `c12a7328-f81f-11d2-ba4b-00a0c93ec93b`. The
`sheng-esp.sparse.img` already contains FAT32 and can be flashed as described
above.

Use a known-good generation or temporary ABL boot for recovery. If the
internal EFI fallback file is missing, U-Boot tries the root image's
extlinux rescue entry. Restoring the boot image alone does not require
erasing the root filesystem.

Single-system hardware testing used a 476.9 GiB `userdata` and a 512 MiB
ESP on a dual-boot GPT. The original bundle exposed a FAT sector-size
mismatch and a generation path issue. After applying the fixes manually,
the seed EFI entry booted, the root filesystem grew to about 448 GiB
available, and the regular generation 1 entry booted on the next restart.
The full single-system GPT was checked offline. Community testers can
report results for that layout in GitHub Issues. Include the device
capacity, CI artifact, post-boot free space, generation handoff, update,
rollback, and rescue results.

A 1 GiB ESP is recommended even on a 128 GB device. The system profile
and closures live on the root partition. The ESP holds boot entries and
copies of the kernel, initrd, and DTB. If you change kernels frequently,
set `boot.loader.systemd-boot.configurationLimit` to limit the number of
generations shown in the menu, and check free space with `df -h /efi`.
