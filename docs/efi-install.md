# EFI 安装与迁移

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
   先手动将正确的 ESP 挂到 `/efi`，再执行原主机的 `nixos-rebuild boot`
   安装首个 EFI 世代。
4. 进入 ABL fastboot，核对设备和槽位，以 `fastboot boot boot.img`
   临时加载对应的 U-Boot。进系统后用 `bootctl status`、`findmnt /`、
   `findmnt /efi` 和 `readlink -f /run/booted-system` 核对结果。
   再执行一次 `nixos-rebuild boot`，重启验证更新并回滚一次。
   临时测试的每次启动都需要重新加载候选镜像。
5. 双系统的持久部署已在 B 槽实测。确认临时启动通过、原 `boot_b`
   备份可用，再从 ABL 只写 `boot_b`。单系统候选的验证使用临时启动。

## 全新安装

1. 先选布局并准备 ESP。单系统使用 `userdata`，在镜像首启扩容前预留
   独立 ESP。盘尾方案已用备份 GPT 离线校验，实际扇区边界按设备分区表
   确定。双系统保留 Android 分区，按[双系统指南](dual-boot.md)准备
   `linux` 和 Linux B 槽。在计算 `linux` 边界时同时留出 ESP。
2. 用对应工作流生成根镜像，单系统用 `build`，双系统用 `build-dual`。
   按对应布局完成 extlinux 基础安装并启动一次，确认根分区和扩容。
   双系统刷写目标为 `linux`，刷写方案须遵循双系统指南。
3. 从上节第 3 步安装 EFI 世代，保留这次 extlinux 首启作为救援世代。

EFI 世代启动失败时，先从 systemd-boot 选上一代。EFI fallback 文件缺失时，
内置 ESP 候选会尝试 extlinux。若要撤销已验证的双系统持久部署，进入 ABL，
核对 B 槽并恢复备份的 `boot_b`。详见[迁移和恢复实测](efi-probe.md#迁移和恢复顺序)。
