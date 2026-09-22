# NetworkManager 无法扫描 Wi-Fi：镜像内 store 属主不是 root

## 现象

- `nmtui` / `nmcli` 完全看不到 Wi-Fi：`nmcli device wifi rescan` 返回
  `Error: No Wi-Fi device found.`，`nmcli device wifi list` 为空。
- 同一条命令的内核侧却正常：`iw dev wlp1s0 scan` 能返回 BSS。
- `NetworkManager` 启动日志里有：

```text
plugin: skip invalid file .../networkmanager-1.56.0/lib/NetworkManager/1.56.0/libnm-device-plugin-wifi.so: file has invalid owner (should be root)
```

- 附带另一条独立的失败：

```text
dispatcher: (1) /etc/NetworkManager/dispatcher.d/03userscript0001 failed (failed): Script ... exited with status 127
```

## 根因

### 1. 主因：刷入的 rootfs 里 `/nix/store/**` 的属主不是 root

Mobile NixOS 的镜像由**非 root 的构建用户**填充：

- `overlay/image-builder/filesystem-image/basic.nix` 只把 `libfaketime` 放进
  `nativeBuildInputs`；
- `modules/rootfs.nix` 用 `cp -prf "$path" ./nix/store` 复制 closure；
- `cp -p` 无法以非 root 身份 chown 到 root（EPERM），于是 staging 目录里的
  文件都归构建用户所有，`mkfs.ext4 -d` 再把这些 uid/gid 原样写进镜像 inode。

NetworkManager 出于安全考虑拒绝 dlopen 属主不是 root 的 device 插件，因此
**NM 没有 Wi-Fi 能力**：设备在网络列表里只是一个"外部连接"，所有 wifi 子命令
都报 No Wi-Fi device found。内核、ath12k、regdb、rfkill 都没有问题。

对照：nixpkgs 官方的 ext4 镜像构建器 `nixos/lib/make-ext4-fs.nix:81` 是
`faketime ... fakeroot mkfs.ext4 ... -d ./rootImage`，并在 `nativeBuildInputs`
里带 `fakeroot`。Mobile NixOS 没有这一步。

本地机制复现（证明 `-d` 直接抄源目录属主）：

```sh
mkdir -p root/sub; echo hi > root/sub/file
mkfs.ext4 -F -q -b 4096 -d root img.raw
debugfs -R 'stat /sub/file' img.raw | grep -E 'User|Group'
# User: 1000  Group: 100   ← 与本机 uid/gid 一致
```

### 2. 次因：仓库添加的 dispatcher 脚本 shebang 无效

`nixos/hardware/hardware.nix` 用 `pkgs.writeScript` 写脚本，脚本体第一行是
`#!/usr/bin/env bash`。`writeScript` 不做 shebang 重写，而 NixOS 没有
`/usr/bin/env`，所以每次 dispatcher 事件都以 127 结束 —— 这段 workaround
从未真正执行过。

## 修复

1. `nixos/hardware/mobile.nix` 的 `buildPhases.copyPhase`：把 `chown -R 0:0 .`
   和 `mkfs.ext4 -d` 放进**同一个 fakeroot 会话**，让 mkfs 读到的属主是 0:0。
   fakeroot 用绝对 store 路径引用（`nativeBuildInputs` 在该子模块里无法追加，
   否则会顶掉 ext4.nix 的 `e2fsprogs` / `make_ext4fs`）。
2. dispatcher 脚本改用 `pkgs.writeShellScript`，删掉手写 shebang。

## 验证

离线检查（刷机前，可直接看镜像内容）：

```sh
sudo mkdir -p /mnt/sheng-rootfs
sudo mount -o loop,ro out/mobile-rootfs/rootfs.img /mnt/sheng-rootfs
stat -c '%u:%g %n' /mnt/sheng-rootfs/nix/store/*networkmanager*/lib/NetworkManager/*/libnm-device-plugin-wifi.so
sudo umount /mnt/sheng-rootfs
```

设备上：

```sh
journalctl -b -u NetworkManager --no-pager | grep -c 'invalid owner'   # 期望 0
journalctl -b --no-pager | grep -c 'exited with status 127'            # 期望 0
nmcli radio
nmcli device                                                          # wlp1s0 应为 disconnected/connected（不是 externally）
nmcli device wifi rescan
nmcli -f SSID,SIGNAL,CHAN device wifi list | head
```

## 影响面与回滚

- 只影响 rootfs 镜像：刷 `linux`，不需要 `boot_b`。
- 整个镜像的 store 属主从构建用户变成 `root:root`，与 nixpkgs 官方行为一致。
- 回滚：还原 `buildPhases.copyPhase` 与 dispatcher 的 `writeShellScript`。

## 后续

修复生效后应重新评估此前的 NM 侧 workaround（`sheng-nm-wifi-sync.service`、
`sheng-nm-wifi-dispatcher`）：它们是在 NM 根本没有 wifi 插件的层上修的，属于
症状处理。按仓库规则先在设备上验证 Wi-Fi 列表正常，再决定是否删除，不先删。
