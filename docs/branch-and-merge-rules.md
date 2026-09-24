# Branch structure and merge rules

[English](branch-and-merge-rules.md) | [简体中文](branch-and-merge-rules_zh.md)

This document defines branch responsibilities, content layering, and the upstream merge
process for this repository. Read it before changing code; `AGENTS.md` only covers
collaboration and flashing boundaries.

## 1. Branch responsibilities

| Branch | Responsibility | Who edits | Artifacts |
|---|---|---|---|
| `sheng` | Read-only mirror of the upstream platform line | `git fetch upstream` + fast-forward only | none |
| `niri` | **Daily driver**: upstream sheng + local platform patches + Niri/Hjem desktop layer | all feature work happens here | `mobileAndroidBootimg`, `mobileRootfsImageNiri` (CI builds images from here) |
| `exp/kernel-sm8550-7.2.6` | Kernel experiment line: `niri` + newest kernel pin | only when changing kernels | boot image + module archive |

Removed legacy branches (content is merged into `niri`; SHAs kept for rollback or
comparison):

| Old branch | SHA | Notes |
|---|---|---|
| `exp/niri-merge-upstream-sheng` | `a8ecd40` | pre-refactor niri+sheng integration content |
| `feat/niri-noctalia-image` | `24c36da` | pre-refactor niri tip used for flashing (7.1.8) |

To bring one back temporarily: `git branch <name> <sha>` or
`git push origin <sha>:refs/heads/<name>`.

## 2. Three content layers — put things in the right one

| Layer | Content | Where | Upstream churn |
|---|---|---|---|
| Upstream platform | boot/charging UI, offline charging, memory policy, firmware injection, kernel pin | do not edit, just follow `sheng` | high (100+ commits / 30 days) |
| Local platform | platform fixes this device needs but upstream lacks | `nixos/modules/sheng-local/*.nix` (our own files) | none → never conflicts |
| Desktop | Niri/Noctalia/Hjem, desktop packages, user config | `nixos/profiles/niri-minimal.nix`, `nixos/home/user.nix`, `nixos/profiles/local/*` | none |

**Hard rule: never add platform features by editing upstream files.** Use the NixOS module
system instead:

- New units or unit fields: define a new service, or append with `lib.mkAfter` /
  `lib.mkBefore` (`wants`, `after`, `requires`, `ExecStartPre/Post`,
  `environment.systemPackages`, `services.udev.extraRules`, `hardware.firmware` are all
  appendable list/lines options).
- Change a string option owned by upstream: use `lib.mkForce`. Note that when upstream
  wraps a whole attrset in `lib.mkForce`, **child `mkForce`/`mkOverride` definitions are
  silently ignored** — that case needs an in-place patch registered in section 4.
- Change a package's behaviour: append `postInstall` via `overrideAttrs` in the flake
  overlay; do not edit the upstream package file.
- Change a profile's behaviour: write your own profile that does
  `imports = [ upstreamProfile ]` and then overrides.

## 3. Merging upstream sheng

```bash
git fetch upstream
git checkout niri
git merge upstream/sheng
```

Resolve conflicts by rule, not by judgement:

| Conflicting file | Rule |
|---|---|
| `nixos/modules/sheng-local/*`, `nixos/profiles/local/*`, `nixos/profiles/niri-minimal.nix`, `nixos/home/user.nix`, `nixos/packages/local/*` | ours (upstream never touches these, so they should not conflict) |
| `nixos/flake.nix`, `nixos/flake.lock` | ours: keep the fork kernel source, hjem/noctalia, and local module wiring while taking upstream's new packages/options |
| `nixos/configuration.nix`, `nixos/hardware/mobile.nix` | upstream wins, except the four registered patches in section 4 (marked `LOCAL PATCH`) |
| `.github/workflows/*`, `README*`, `TODO*`, `docs/*`, `AGENTS.md`, `build-nixos-rootfs.sh`, `examples/*` | union; CI files follow ours |

`git rerere` is enabled in this clone (`rerere.enabled=true`, `rerere.autoupdate=true`), so
a conflict resolution is replayed automatically next time. Fresh clones must enable it:

```bash
git config rerere.enabled true
git config rerere.autoupdate true
```

## 4. Registered in-place patches (four, no more)

| File | Patch | Why it cannot live in a local module |
|---|---|---|
| `nixos/hardware/mobile.nix` | wrap the rootfs `mkfs.ext4` phase in `fakeroot` and `chown -R 0:0` | upstream defines the whole `mobile.generatedFilesystems.rootfs` with `lib.mkForce`, which swallows child overrides; non-root-owned files make NetworkManager refuse the wifi plugin (empty `nmtui` list) |
| `nixos/hardware/mobile.nix` | delete `boot.bootspec.enable = ...` | the option was removed in current nixpkgs and asserts when defined, breaking the `sheng-stage2` evaluation; a module cannot cancel another module's definition |
| `nixos/configuration.nix` | `services.journald.extraConfig` → `services.journald.settings.Journal` | same removed-option assertion |
| `nixos/configuration.nix` | wireplumber `libpipewire-module-filter-chain` component `type` `pw-module` → `pw-module-client` | the key is a json leaf inside `attrsOf (attrsOf json)`; overriding it would copy upstream's EQ graph and freeze their tuning, so a one-line edit is safer (otherwise the whole device is silent) |

`nixos/scripts/sheng-check.sh` also carries locally added diagnostics (purely additive,
untouched by upstream for 30 days) and is treated as ours.

After every merge, verify the patches are still present:

```bash
grep -n 'LOCAL PATCH' nixos/configuration.nix nixos/hardware/mobile.nix
```

## 5. Where new work goes

1. Desktop (session, packages, theming, keybindings) → `nixos/profiles/niri-minimal.nix`,
   `nixos/profiles/local/*`, `nixos/home/user.nix`.
2. Platform (module loading, services, udev, firmware, power) →
   `nixos/modules/sheng-local/`.
3. Kernel (DTS, drivers, config) → the kernel repository `DotRedstone/linux-sheng` (or
   this branch's kernel fork); here only the kernel pin changes.
4. If an upstream file really must change: try the override techniques in section 2 first;
   only register an in-place patch when none works, and add a row here.

## 6. Verification requirements

Evaluation-level (do this locally after every change):

```bash
nix build --dry-run --offline --system aarch64-linux ./nixos#mobileAndroidBootimg
nix build --dry-run --offline --system aarch64-linux ./nixos#mobileRootfsImageNiri
nix build --dry-run --offline --system aarch64-linux ./nixos#nixosConfigurations.sheng-stage2.config.system.build.toplevel
nix build --dry-run --offline --system aarch64-linux ./nixos#checks.aarch64-linux.generationMenuRenderer
```

Behavioural equivalence (recommended after refactors and merges): evaluate and compare
these `nixosConfigurations.sheng-niri.config` values before and after: rootfs
`buildPhases.copyPhase`, `boot.kernelParams`, the `hardware.firmware` aggregate, udev
rules, `environment.systemPackages`, `systemd.services.{sheng-wifi-modules,
sheng-nm-wifi-sync, sheng-touchscreen-modules, xiaomi-sheng-thp, sheng-devauth}`,
`services.journald.settings`, `services.openssh.settings.PasswordAuthentication`, the
wireplumber components, and the Noctalia brightness config.

Device-level: boot animation, offline charging, touch, keyboard-cover authentication,
`nmtui` list, and fingerprint can only be confirmed on hardware after flashing.

## 7. Flash boundaries

| Change | Build | Flash |
|---|---|---|
| kernel config / patch / DTS / initrd / cmdline | `mobileAndroidBootimg` | `boot_b` |
| kernel modules (`.ko`) | kernel archive | `/lib/modules` on `linux` (or on-device `nixos-rebuild`) |
| firmware / systemd / udev / packages / desktop / rootfs layout | `mobileRootfsImageNiri` | `linux` |

On-device updates without flashing images are documented in `docs/nixos-rebuild.md`: the
flake's `sheng-niri` / `sheng-stage2` configurations exist for that path, and they require
the flake's kernel pin to match the kernel already flashed into `boot_b`.

CI note: `build-nixos-rootfs.sh` converts the image to **Android sparse format**
(`img2simg`, so it can be flashed with fastboot directly). Any CI step that mounts or reads
the image contents must run `simg2img` first and mount the raw copy, otherwise it fails
with `wrong fs type, bad option, bad superblock`. Upstream's verification steps assume a
raw image, so re-check this after every upstream merge (see the "Verify hardware payloads
in rootfs" step in `nixos-rootfs.yml`).
