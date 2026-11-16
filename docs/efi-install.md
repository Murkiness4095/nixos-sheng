# EFI 安装与迁移


[English](efi-install.en.md) · 简体中文

## 哪些步骤可以自动化

已有系统只刷 U-Boot 无法完成迁移。ESP 还需要 systemd-boot 和基于当前主机配置生成的启动条目。ESP 准备好后，迁移工具会挂载并安装条目，再用 ABL fastboot 临时启动验证。

全新安装可用下文的 EFI 安装包直接首启。它已包含启动文件，但仍需按设备 GPT 准备独立 ESP。原有 extlinux 镜像继续提供。

EFI 使用 U-Boot 从内置 ESP 加载 systemd-boot。两种布局使用同一个
ESP 分区标签 `sheng-esp`，但根分区和 U-Boot 镜像必须按下表配对。

| 布局 | 根 PARTLABEL | EFI 配置参考 | ARM CI 的 U-Boot 产物 |
| --- | --- | --- | --- |
| 单系统 | `userdata` | `sheng-efi-generations` | `sheng-efi-internal-single` |
| 双系统 | `linux` | `sheng-dual-efi-generations` | `sheng-efi-internal-dual` |

在 GitHub Actions 的 **EFI experiments** 中选择 `task=internal-esp`
构建 U-Boot，下载对应产物里的 `boot.img`，并与构建日志的 SHA-256 核对。
两种镜像的源码和实测记录见 [EFI 实测记录](efi-probe.md)。

## 已安装 extlinux 的设备

1. 确认运行系统的根分区和当前 A/B 槽位，备份当前启动镜像及已有 ESP。
   双系统按验证过的 Android A、Linux B 布局操作。保留可启动的 extlinux
   世代及 `/boot` 中的 DTB。
2. 准备独立的 GPT EFI System 分区，标签为 `sheng-esp`，格式为 FAT32。
   512 MiB 是实测参考值，容量还要覆盖计划保留的内核、initrd 和更新余量。
   如果没有空闲区间，先备份并确认可恢复。已有 ext4 需要缩小时，
   必须先离线缩小文件系统，再缩短其 GPT 分区。
3. 在原主机配置上采用对应 EFI 配置的设置，保留账户、桌面及存储配置。
   参考仓库的 `sheng-efi-generations`，它启用 initrd、EFI stub 和
   systemd-boot 的 DTB 安装，并加入混合世代补丁及 `/efi` 自动挂载。
   推荐从当前 extlinux 系统用下面的命令安装首个 EFI 世代。

   ```sh
   sudo nix run .#sheng-efi-migrate
   ```

   如果平时用 `--flake <路径>#<主机名>` 更新，在命令末尾用 `-- --flake <路径>#<主机名>` 传入相同的路径和主机名。
   `nixos-rebuild boot` 会立即写入 ESP，而新配置的自动挂载要等新世代启动后
   才会生效。迁移工具仅在 `/efi` 尚未挂载时挂载 ESP。分区缺失或挂载失败时
   会跳过构建命令，已挂载但设备不对时迁移工具会在构建前报错。
4. 进入 ABL fastboot，核对设备和槽位，以 `fastboot boot boot.img`
   临时加载对应的 U-Boot。进系统后用 `bootctl status`、`findmnt /`、
   `findmnt /efi` 和 `readlink -f /run/booted-system` 核对结果。
   EFI 世代启动后会自动挂载 `/efi`。日常更新直接运行 `nixos-rebuild boot`。
   重启验证更新，再运行 `sudo nixos-rebuild boot --rollback` 并重启，确认上一代可用。
   临时测试的每次启动都需要重新加载候选镜像。

## 持久部署 U-Boot

迁移工具安装的 EFI 文件会保存在 ESP。正常重启使用槽内的 U-Boot，
所以要让正常重启进入 EFI，还需把通过临时启动验证的同一镜像写入 Linux 槽。

- 双系统的 B 槽持久部署已实测。使用双系统产物，仅写 `boot_b`。
- 单系统使用单系统产物。以下 B 槽步骤适用于已用 B 槽临时启动并确认
  根分区为 `userdata` 的设备。现有 `userdata` 上已实测 B 槽持久启动、
  世代更新、回滚和冷启动。单系统本身不限定 A/B 槽。

确认原 `boot_b` 的备份可以恢复，在 ABL fastboot 中核对设备和槽位。
只有 `fastboot getvar current-slot` 显示 `b` 时才继续。

```sh
fastboot flash boot_b boot.img
fastboot reboot
```

正常启动后用 `bootctl status` 和 `findmnt /efi` 确认 EFI 启动及 ESP 挂载。
如需恢复，从 ABL 将原镜像写回同一个 `boot_b`。

## 全新安装：直接从 EFI 首启

**原厂 GPT 没有 `sheng-esp`。先创建分区，再刷镜像。** 安装包提供 ESP
的文件系统内容。刷写镜像不会在 GPT 中创建分区。现有 GPT 没有足够的未分配
空间时，先备份并按实际布局腾出空间。确认 `sheng-esp` 存在且容量足够后，
再开始刷写。

```text
检查 GPT → 创建并核对 sheng-esp → 解压 rootfs
  → 刷 rootfs → 刷 ESP → 临时启动 boot.img
  → 确认 systemd-boot 和正式世代 → 持久刷入启动槽
```

| 安装包文件 | 写入目标 |
| --- | --- |
| `sheng-rootfs.sparse.img.zst` | 在电脑上运行 `zstd -d sheng-rootfs.sparse.img.zst`。把解压出的 `sheng-rootfs.sparse.img` 写到单系统的 `userdata` 或双系统的 `linux`。 |
| `sheng-esp.sparse.img` | 只写入已创建的 `sheng-esp`。ABL 未暴露该分区时，按下文使用 Recovery。 |
| `boot.img` | 先在 ABL 用 `fastboot boot boot.img`。通过验证后写入确认过的 Linux 启动槽。已验证的双系统布局只写 `boot_b`。 |

**EFI experiments** 工作流选择 `task=install-bundle`，并选择 `layout=single`
或 `layout=dual`。用 `esp_size_mib` 选 512 或 1024 MiB，默认 1024。下载同一产物中的 `boot.img`、`sheng-rootfs.sparse.img.zst`
和 `sheng-esp.sparse.img`。先运行 `sha256sum -c SHA256SUMS`，然后核对
`manifest.txt` 的布局和根分区标签。完整单系统布局上的整套镜像
的直接首启还没有真机验证。需要已验证路径时，先装 extlinux，再按上节迁移。

1. 按目标设备 GPT 预留与镜像同样大或更大的独立 EFI System Partition，GPT 分区名为
   `sheng-esp`。单系统给 `userdata` 留出 ESP 空间，须在 rootfs 首启扩容前完成；
   双系统按[双系统指南](dual-boot.md)保留 Android A 槽和 Recovery，并在
   `linux` 之外留出 ESP。不要照抄其他设备的扇区号。
2. 解压 rootfs 的 Zstandard 外层，把 Android sparse rootfs 写到清单指定的根分区。
   ESP 镜像是另一份 Android sparse 镜像，目标只能是 `sheng-esp`；它会覆盖
   现有 ESP 内容。如果 ABL 不暴露该分区，从 Recovery 使用 `simg2img` 转成
   raw，再按 GPT 分区名核对目标后写入；不能直接用 `dd` 写 sparse 文件。
3. 用包里的 `boot.img` 在 ABL 临时启动。确认根分区正确、`/efi` 已挂载，
   并检查 `journalctl -b -u sheng-finish-efi-install` 和 `bootctl list`：
   首启条目应已换成正常的 NixOS 世代条目。之后用 `nixos-rebuild boot --flake /etc/nixos`
   更新，重启验证新世代，再部署到上文确认的 Linux 启动槽。

遇到无法启动的问题，优先用现有可用世代或 ABL 临时启动救援。内置 EFI 文件缺失时，
U-Boot 会尝试 rootfs 里的 extlinux 救援条目。只恢复启动镜像不需要擦除 rootfs。

单系统真机测试使用双系统 GPT 上的 476.9 GiB `userdata` 和现有 512 MiB
ESP。首版产物暴露了 FAT 扇区大小和世代路径两个问题。手动应用对应修正后，
从 EFI 首启条目启动成功，根文件系统扩容后约 448 GiB 可用，随后从正式第 1
世代条目再次启动成功。完整单系统 GPT 已离线检查。欢迎在 GitHub Issues
反馈完整单系统布局的实测结果，附上设备容量、CI 产物、首启容量和世代接管、
更新、回滚及救援的结果。

ESP 容量由保留的引导文件决定。128 GB 存储也建议预留 1 GiB。世代的
profile 和系统闭包在根分区，ESP 保存启动条目以及内核、initrd 和 DTB 副本。
经常更换内核时，可设置 `boot.loader.systemd-boot.configurationLimit`
限制保留在菜单中的世代数，并用 `df -h /efi` 查看剩余容量。
