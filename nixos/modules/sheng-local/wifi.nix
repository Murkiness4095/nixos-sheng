# ---
# Module: sheng-local Wi-Fi / NetworkManager
# Description: Keeps NetworkManager aware of sheng's ath12k interface so nmtui and nmcli list networks
# Scope: System
# Notes:
# - 上游只有 sheng-wifi-modules（两遍 init 加载模块）。这里补三件事，都只做追加，
#   不改上游文件：
#   1. 让 NetworkManager 显式依赖 sheng-wifi-modules；
#   2. 启动后重新把 wlp1s0 交给 NM 并触发一次 rescan；
#   3. NM dispatcher 兜底，接口晚到时同样接管并 rescan。
# - 依赖的根因：NM 在 wlan0 改名成 wlp1s0 之前完成内部初始化时会漏掉 netlink
#   事件，接口停在 unmanaged，于是 nmtui 列表为空，而 `iw dev wlp1s0 scan` 正常。
# ---
{ lib, pkgs, ... }:

{
  systemd.services.NetworkManager = {
    wants = lib.mkAfter [ "sheng-wifi-modules.service" ];
    after = lib.mkAfter [ "sheng-wifi-modules.service" ];
  };

  systemd.services.sheng-nm-wifi-sync = {
    description = "Re-attach sheng Wi-Fi to NetworkManager after boot";
    wantedBy = [ "multi-user.target" ];
    after = [
      "NetworkManager.service"
      "sheng-wifi-modules.service"
    ];
    wants = [
      "NetworkManager.service"
      "sheng-wifi-modules.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for any ath12k wireless interface to appear. udev may rename
      # wlan0 -> wlp1s0 asynchronously, so discover the actual name instead
      # of hard-coding one. Prefer the renamed wlp* name over the transient
      # wlan* name, and give udev a moment to finish renaming.
      iface=""
      for attempt in $(seq 1 30); do
        iface="$(${pkgs.coreutils}/bin/ls /sys/class/net 2>/dev/null \
          | ${pkgs.gawk}/bin/awk '/^wlp[0-9]+s[0-9]+$/ { print; exit }
              /^wlan[0-9]+$/ { if (!w) w=$0 }
              END { if (w) print w }')"
        if [ -n "$iface" ]; then
          break
        fi
        sleep 1
      done
      if [ -z "$iface" ]; then
        echo "No wireless interface appeared; skipping NetworkManager sync" >&2
        exit 0
      fi
      echo "Discovered wireless interface: $iface"
      # Let udev finish any in-flight rename before we touch the interface.
      sleep 2

      # The ath12k two-pass init can leave the interface administratively down
      # or soft-blocked by rfkill. NetworkManager then keeps the device as
      # unavailable/unmanaged and nmtui shows an empty network list, while
      # `iw dev <iface> scan` works fine once the interface is brought up.
      ${pkgs.iproute2}/bin/ip link set "$iface" up || true
      sleep 1
      if [ -d /sys/class/rfkill ]; then
        ${pkgs.util-linux}/bin/rfkill unblock wifi || true
      fi

      nmcli=${pkgs.networkmanager}/bin/nmcli

      # Wait for NetworkManager itself to be reachable on D-Bus.
      for attempt in $(seq 1 30); do
        if "$nmcli" -t -f RUNNING general 2>/dev/null | grep -q "^running"; then
          break
        fi
        sleep 1
      done

      state="$("$nmcli" -t -f DEVICE,STATE device 2>/dev/null \
        | ${pkgs.gawk}/bin/awk -F: -v dev="$iface" '$1 == dev { print $2 }')"
      case "$state" in
        unmanaged)
          echo "$iface reported unmanaged; forcing managed" >&2
          "$nmcli" device set "$iface" managed yes || true
          sleep 2
          ;;
        unavailable)
          # NM sees the device but does not yet consider it ready. Re-set
          # the managed flag so NM re-runs its Wi-Fi plugin probe instead
          # of leaving the device stuck.
          "$nmcli" device set "$iface" managed yes >/dev/null 2>&1 || true
          sleep 2
          ;;
        "")
          echo "$iface missing from NetworkManager device list" >&2
          ;;
      esac

      # Always trigger a fresh rescan so nmtui shows surrounding networks
      # after login, even when the first NM scan happened before the
      # interface was renamed and reported zero results.
      "$nmcli" device wifi rescan ifname "$iface" 2>/dev/null || true
    '';
  };

  # NetworkManager dispatcher hook: if a Wi-Fi device appears after the boot
  # sync service has already run (or if the sync service missed the rename),
  # force it managed and trigger a rescan so nmtui shows networks.
  networking.networkmanager.dispatcherScripts = lib.mkAfter [
    {
      # `writeScript` does not rewrite the interpreter line, so a plain
      # `#!/usr/bin/env bash` never resolves on NixOS and every dispatcher
      # event exits with status 127 (journal: 03userscript0001 failed).
      source = pkgs.writeShellScript "sheng-nm-wifi-dispatcher" ''
        iface="$1"
        event="$2"
        echo "sheng-nm-wifi-dispatcher: event=$event iface=$iface" >&2
        case "$event" in
          device-added|up)
            case "$iface" in
              wlan*|wlp*)
                echo "sheng-nm-wifi-dispatcher: ensuring $iface is managed and rescanning" >&2
                ${pkgs.networkmanager}/bin/nmcli device set "$iface" managed yes || true
                ${pkgs.networkmanager}/bin/nmcli device wifi rescan ifname "$iface" || true
                ;;
            esac
            ;;
        esac
      '';
      type = "basic";
    }
  ];
}
