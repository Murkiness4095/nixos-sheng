# Android / NixOS 双系统构建

参考 [debian-sheng](https://github.com/ianchb/debian-sheng#flashing-to-your-device)
使用独立 `linux` 分区，并通过 A/B 启动槽选择系统。第一阶段不在 U-Boot 内直接加载安卓。

| 项目 | 单系统 | 双系统 |
| --- | --- | --- |
| NixOS 配置 | `nixosConfigurations.sheng` | `nixosConfigurations.sheng-dual` |
| 镜像构建 | `nix build .#nixos` | `nix build .#nixos-dual` |
| U-Boot 构建 | `nix build .#u-boot` | `nix build .#u-boot-dual` |
| 根分区 | `userdata` | `linux` |
| 默认主机名 | `sheng` | `sheng-dual` |
| 工作流 | `build` | `build-dual` |

两种模式共用内核、设备树、固件和服务。U-Boot 共用源码及内存/fastboot 修复补丁，
双系统版本将读取菜单、正常启动和救援启动的分区统一改为 `linux`。

`build-dual` 独立运行，比较两种配置的内核、DTB、关键服务及除根分区以外的启动参数。
产物为 `sheng-dual-flashable`，包含 `sheng-boot-dual.img` 和
`sheng-rootfs-dual.sparse.img.zst`。现有单系统工作流和产物名称保持不变。

## 设备上的更新

双系统镜像仍在 `/etc/nixos` 中携带仓库源码，使用对应配置更新：

```sh
sudo nixos-rebuild boot --flake /etc/nixos#sheng-dual
sudo reboot
```

双系统主机名为 `sheng-dual`，也支持 `nixos-rebuild --flake /etc/nixos` 按主机名选择配置。
个人配置若使用 `lib.shengSystem`，应显式设置 `sheng.rootfs.partlabel = "linux";`。
不要将双系统设备更新为默认的 `userdata` 根分区配置。

## 迁移顺序

先保留可用的 `userdata` 单系统，在 `linux` 上部署并临时启动验证双系统版本。
确认新系统正常后，再安排 Linux 启动槽及匹配的安卓启动链，并恢复安卓的数据分区。
恢复安卓之前不得格式化当前运行单系统的 `userdata`。

现有 `fastboot-flash` 和 `flash-rootfs` 是单系统工具，不能用于双系统部署：
前者写两个 boot 槽，后者针对 userdata。双系统只操作确定用于 Linux 的启动槽及 `linux` 分区。
Android OTA 对 A/B 槽位的覆盖需另行处理；不能把占用一个启动槽后的更新方式当作纯安卓使用。

## 已有安卓和 linux 分区时安装

以下示例要求安卓 A 槽已能正常启动，`linux` 分区已经建立且允许覆盖。
它不负责分区、恢复已经被单系统覆盖的安卓数据，或修复不完整的安卓启动链。
先确认 `fastboot devices` 只有目标设备，再执行：

```sh
zstd -d sheng-rootfs-dual.sparse.img.zst
fastboot erase dtbo_b
fastboot flash boot_b sheng-boot-dual.img
fastboot erase linux
fastboot flash linux sheng-rootfs-dual.sparse.img
fastboot set_active b
fastboot reboot
```

必须先擦除 `linux`，避免 Android sparse 镜像中的 DONT_CARE 区域保留旧文件系统数据。
不要擦除 `userdata`、`metadata` 或 A 槽分区；它们属于安卓。

第一阶段通过电脑上的 fastboot 切换启动槽，U-Boot 菜单暂不直接切换安卓：

```sh
# NixOS 中先进入 fastboot；也可用电源键和音量下键进入。
sudo systemctl reboot --reboot-argument=bootloader

# 电脑上选择安卓 A 槽
fastboot set_active a
fastboot reboot

# 从安卓进入 fastboot 后，电脑上选择 NixOS B 槽
fastboot set_active b
fastboot reboot
```

## 设备验证范围

已用 GitHub CI 双系统产物在独立 `linux` 分区启动，验证 B 槽启动成功标记、
标准 `nixos-rebuild boot`、新增配置世代后的启动，以及 `--rollback` 回退到原始 CI 世代。
显示接口、声卡与 UCM、触摸服务、指纹设备枚举、加速度计、环境光及 Wi-Fi 均完成基础检查；
这些检查不等于音频播放、指纹录入或手写笔绘画的完整测试。
安卓恢复与两个系统之间的切换仍在设备验证中，完成前保持实验状态。
