# 5 GHz Wi-Fi invisible / unable to connect: investigation notes (unresolved)

[English](wifi-5ghz-160mhz.md) | [简体中文](wifi-5ghz-160mhz_zh.md)

Status: **unresolved**. 2.4 GHz works normally; 5 GHz is unusable with the current AP
configuration, so the device is used on 2.4 GHz only. This document preserves what was
already ruled out so the next investigation does not start from scratch.

## Symptoms

- `nmcli -f SSID,CHAN,FREQ dev wifi list` lists only 2.4 GHz APs (2412/2462 MHz) and no 5 GHz BSS.
- The known 5 GHz SSID left this in the NetworkManager journal:
  ```
  device (wlp1s0): Activation: (wifi) association took too long, failing activation
  ```
  so it was visible at some point and failed to associate, then became invisible.
- Behaviour varies per boot (sometimes the network is listed, sometimes not).

## Ruled out

| Hypothesis | Evidence | Verdict |
|---|---|---|
| Regulatory domain not applied | `iw reg get` → `country CN: DFS-FCC`; `dmesg` → `cfg80211: Loading compiled-in X.509 certificates for regulatory database`; `/lib/firmware/regulatory.db{,.p7s}` present | ruled out |
| 5 GHz channels disabled | `iw phy`: 5180–5240 [36–48] 23 dBm and 5745–5825 [149–165] 33 dBm usable; only 5500–5720 [100–144] `disabled` | ruled out (an AP on 100–144 would be legitimately invisible) |
| Incomplete WCN7850 board database | `/lib/firmware/ath12k/WCN7850/hw2.0/`: `amss.bin` 6,271,040, `board-2.bin` 2,254,080, `m3.bin` 299,660 — byte-identical to `sheng-firmware-full@719086ce…` pinned by the flake | ruled out |
| Missing firmware warm-up (upstream issue #21 fix) | `dmesg` shows ath12k initialized twice (15.6 s and 20.5 s, with an unload in between), i.e. the two-pass init in `sheng-wifi-modules.service` ran | already fixed, ruled out |
| Scan random MAC / power save dropping off-channel results | `nixos/configuration.nix`: `wifi.scanRandMacAddress = false`, `powersave = false` | already fixed, ruled out |

## Remaining hypothesis (unverified)

**The AP uses 160 MHz while the CN regulatory database only allows 80 MHz.** Basis:

- Every CN rule printed by `iw reg get` is capped at 80 MHz:
  ```
  (5170 - 5250 @ 80) ... NO-OUTDOOR, AUTO-BW
  (5250 - 5330 @ 80) ... DFS, AUTO-BW
  (5735 - 5835 @ 80) ... AUTO-BW
  ```
- The phy capability list marks 5 GHz `NO-320MHZ` and 2.4 GHz `NO-80MHZ, NO-160MHZ, NO-320MHZ`.
- The AP in question is explicitly configured for **160 MHz** on 5 GHz.

A 160 MHz channel spans 5170–5330 (crossing into the DFS range), which exceeds the 80 MHz
the regulatory rules allow. The usual outcome is either an invisible BSS or a visible BSS
whose association fails and times out with `association took too long` — matching both
observations.

A phone connecting to the same AP is not a counter-argument: Android uses its own
country/certification data and is not bound by the Linux `regulatory.db`.

## How to verify next time (cheapest first)

1. **Set the AP's 5 GHz bandwidth to 80 MHz** (or move it to the 149–165 range at 80 MHz) and
   retry. If it works immediately, the hypothesis holds.
2. Disconnect first, then scan raw, to separate "invisible" from "cannot associate":
   ```sh
   sudo systemd-run --unit=wifi-5g-test --collect --property=Type=oneshot \
     --setenv=PATH=/run/current-system/sw/bin \
     /bin/sh -c '
     exec > /tmp/5g-test.txt 2>&1
     nmcli device disconnect wlp1s0 || true; sleep 3
     iw dev wlp1s0 scan > /tmp/scan-all.txt 2>&1
     echo "BSS: $(grep -c "^BSS" /tmp/scan-all.txt)  2.4G: $(grep -c "freq: 24" /tmp/scan-all.txt)  5G: $(grep -c "freq: 5" /tmp/scan-all.txt)"
     iw dev wlp1s0 scan freq 5180 5200 5220 5240 5745 5765 5785 5805 5825 | grep -E "^BSS|SSID:|freq:"
     nmcli device connect wlp1s0 || true
   '
   ```
   Note: a transient unit started with `systemd-run` does **not** inherit the login shell's
   `PATH`; without `--setenv=PATH=/run/current-system/sw/bin` every command reports
   "command not found". Also, scanning while associated is limited to off-channel windows and
   ath12k frequently returns no 5 GHz BSS at all — such an empty result is not evidence that
   the 5 GHz radio is broken.
3. If 80 MHz still does not work, take the `dmesg | grep -i ath12k` output and the
   NetworkManager journal from the failing boot to `DotRedstone/linux-sheng` and discuss the
   ath12k/WCN7850 side there.

## Related but separate observation

After a connection is established, `dmesg` occasionally floods with (the kernel is built with
`CONFIG_ATH12K_DEBUG=y`):

```
ath12k_wifi7_pci 0000:01:00.0: dp_tx: failed to find the peer with peer_id 0
```

This is a driver debug message about a peer missing from the data path. No causal link to
5 GHz visibility has been established, but it is the first lead if the same instability
appears on an AP that is on 36–48 / 149–165 at 80 MHz.

## Scope

Documentation only, no code change. The existing implementation lives in
`nixos/hardware/hardware.nix` (`sheng-wifi-modules` two-pass init, `sheng-nm-wifi-sync`) and
`nixos/configuration.nix` (NetworkManager scan/power-save settings).
