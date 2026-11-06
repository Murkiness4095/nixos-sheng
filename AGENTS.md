# Working on nixos-sheng

## Start here

- Read `docs/HANDOVER.md` for the verified baseline, layout, evidence, and maintenance workflow.
- Read `TODO.md` for open tasks and their acceptance criteria; consult `docs/peripheral-validation.md` before making hardware claims.
- Read `docs/history/2026-11-06-07.md` when investigating the original boot failure, upgrade, or dual-system migration.
- Historical notes are evidence, not universal hardware invariants. The source and current device inspection take precedence over stale paths or defaults.

## Project decisions

- This is standard NixOS booted by U-Boot. Preserve normal rebuild and generation rollback.
- Use Debian-sheng's actual source, release packages, firmware/configuration and service integration first. Develop an independent solution only where that reference is absent or does not solve a measured issue.
- Preserve both product modes: single uses `userdata`; dual uses `linux`, Android A and Linux B in the tested layout. Never silently change the default single-system output to dual.
- Android OTA automation is explicitly out of scope. The owner accepts selective Android reflashing. Preserve Linux and recovery when reviewing a ROM's scripts; do not reintroduce OTA work as a required milestone.
- Prefer GitHub's native aarch64 CI for kernel, bootloader and full image builds. Local evaluation, image inspection and cached diagnostic tools are fine. Do not silently start an expensive kernel build on the owner's x86 computer or tablet.

## Device work

- Establish current USB mode, slot, root PARTLABEL, hostname and system path before changing anything. DHCP addresses, `/dev/sdX` letters, generation numbers and `/tmp` tools are not stable identifiers.
- Do not use `fastboot-flash`, `flash-uboot` or `flash-rootfs` on a dual-system device: their hardcoded writes target both boot slots or `userdata`.
- A rootfs erase is not needed to update NixOS or restore only its bootloader. A tested temporary `fastboot boot` is preferable while evaluating a new U-Boot.
- Linux USB serial is not a U-Boot console. Keep a working control path and a known-good generation; do not assume black screen means Linux never ran.
- Follow the current user's authorized scope and continue necessary work without inventing approval gates. A past authorization to discard old Mobile NixOS data was specific to that old `linux` content, not a standing authorization to erase future user data.
- Keep private keys, Wi-Fi profiles, raw device backups, signed download URLs and biometric data out of Git and public issue/PR bodies. Local evidence under `artifacts/sheng-debug/` is not a publication directory.
- Enrollment tests need user participation. Honour requested deletion of test fingerprints, and verify deletion. A result from the wrong physical finger or a thermal disconnect is not a passing authentication test.

## Changes and evidence

- Record source commit, lock file, CI run, system/kernel/DTB paths and relevant boot image hashes. Document what actually ran, not just what was intended to run.
- Build success and configuration equality do not prove every physical peripheral works. Keep status scoped to the specific interaction measured.
- Keep a hardware change small, use CI, test a candidate generation, verify rollback, then update the status and handover documents. Avoid rewriting the bootloader to address an unlocalized black-screen report.
- Keep Linux-root and Android-root paths distinct in examples. Read each ROM's flashing scripts before invoking any part of them.
- For docs-only changes, check facts, relative links and `git diff --check`; do not rebuild a kernel merely to validate prose.
