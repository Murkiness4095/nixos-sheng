# 5GHz Wi-Fi 搜不到 / 连不上：排查记录（未解决，留档）

[English](wifi-5ghz-160mhz.md) | [简体中文](wifi-5ghz-160mhz_zh.md)

状态：**未解决**。2.4GHz 完全正常，5GHz 在本机 AP 配置下不可用，当前按「只用 2.4GHz」使用。
本文档保存已经做过的证伪与剩余假设，避免下次重复排查。

## 现象

- `nmcli -f SSID,CHAN,FREQ dev wifi list` 只列出 2.4GHz 的 AP（2412/2462 MHz），没有任何 5GHz BSS。
- 连过的 `ImmortalWrt-5G` 在 NetworkManager 日志里留下：
  ```
  device (wlp1s0): Activation: (wifi) association took too long, failing activation
  ```
  即曾经看得见、关联超时失败，之后又变成完全看不见。
- 重新启动后行为随机（有时能搜到，有时不能）。

## 已排除的原因

| 假设 | 证据 | 结论 |
|---|---|---|
| 监管域没生效 | `iw reg get` → `country CN: DFS-FCC`；`dmesg` → `cfg80211: Loading compiled-in X.509 certificates for regulatory database`；`/lib/firmware/regulatory.db{,.p7s}` 存在 | 排除 |
| 5GHz 信道被禁用 | `iw phy`：5180–5240 [36–48] 23 dBm、5745–5825 [149–165] 33 dBm 均可用；仅 5500–5720 [100–144] `disabled` | 排除（AP 若在 100–144 才会"合法搜不到"） |
| WCN7850 板级数据库不完整 | `/lib/firmware/ath12k/WCN7850/hw2.0/`：`amss.bin` 6,271,040、`board-2.bin` 2,254,080、`m3.bin` 299,660 —— 与 flake 钉的 `sheng-firmware-full@719086ce…` 逐字节一致 | 排除 |
| 缺少固件预热（上游 issue #21 的修复） | `dmesg` 中 ath12k 被完整初始化两次（15.6s / 20.5s，中间执行卸载），即 `sheng-wifi-modules.service` 的两遍 init 生效 | 已修复项，排除 |
| 扫描随机 MAC / 省电导致离频扫描丢失 | `nixos/configuration.nix`：`wifi.scanRandMacAddress = false`、`powersave = false` | 已修复项，排除 |

## 剩余假设（未验证）

**AP 使用 160MHz，而 CN regdb 只允许 80MHz。** 依据：

- `iw reg get` 的 CN 规则每条都标 `@ 80`（该频段最大信道宽度）：
  ```
  (5170 - 5250 @ 80) ... NO-OUTDOOR, AUTO-BW
  (5250 - 5330 @ 80) ... DFS, AUTO-BW
  (5735 - 5835 @ 80) ... AUTO-BW
  ```
- phy 能力表中 5GHz 标 `NO-320MHZ`，2.4GHz 标 `NO-80MHZ, NO-160MHZ, NO-320MHZ`。
- 现场 AP 的 5GHz 明确配置为 **160MHz**。

160MHz 信道需要跨越 `5170–5330`（进入 DFS 段），超出 reg 规则允许的 80MHz。常见后果是客户端
要么看不到该 BSS、要么看得到但协商失败并卡到 `association took too long`，与观察到的两个现象都吻合。

同一位置手机可以正常连 5GHz 不构成反证：Android 使用自己的国家/认证数据，不受 Linux
`regulatory.db` 约束。

## 下次怎么验证（按成本从低到高）

1. **把 AP 的 5GHz 带宽改成 80MHz**（或换到 149–165 段、80MHz）后重试。如果立刻可用，假设成立。
2. 断开连接后做裸扫描，区分"看不见"和"连不上"：
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
   注意：`systemd-run` 起的 transient unit 不继承登录 shell 的 `PATH`，必须显式
   `--setenv=PATH=/run/current-system/sw/bin`，否则所有命令报"未找到命令"。
   另外**已连接状态下的扫描会受 off-channel 窗口限制**，ath12k 常常一条 5G 都不返回，
   这类空结果不能作为"5G 射频坏了"的证据。
3. 若 80MHz 仍不可用，再带上故障启动时段的 `dmesg | grep -i ath12k` 与 NetworkManager 日志，
   到内核仓库 `DotRedstone/linux-sheng` 讨论 ath12k/WCN7850 侧问题。

## 相关但独立的观察

连接建立后 dmesg 偶发刷屏（内核开了 `CONFIG_ATH12K_DEBUG=y`）：

```
ath12k_wifi7_pci 0000:01:00.0: dp_tx: failed to find the peer with peer_id 0
```

这是驱动在数据路径上找不到 peer 的调试信息，与 5GHz 可见性暂未建立因果关系，但如果后续在
36–48 / 149–165 且 80MHz 的 AP 上仍然不稳定，它是首要线索。

## 影响面

仅记录，没有代码改动。相关既有实现见 `nixos/hardware/hardware.nix`（`sheng-wifi-modules`
两遍初始化、`sheng-nm-wifi-sync`）与 `nixos/configuration.nix`（NM 的扫描/省电设置）。
