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
也可继承 `inputs.nixos-sheng.nixosConfigurations.sheng-dual.extendModules { modules = [ ... ]; }`，
此时已继承分区设置，不需重复声明。它也会继承主机名 `sheng-dual`；如需改名，使用
`networking.hostName = lib.mkForce "自定义名称";`。完整示例见
[最小样板](../examples/minimal/README.md) 和 [flake-parts 样板](../examples/flake-parts/README.md)。
启用 tmpfs 不改变分区选择的必要性，`linux` 此时是底层持久化分区。
不要将双系统设备更新为默认的 `userdata` 根分区配置。

## 迁移顺序

先保留可用的 `userdata` 单系统，在 `linux` 上部署并临时启动验证双系统版本。
确认新系统正常后，再安排 Linux 启动槽及匹配的安卓启动链，并恢复安卓的数据分区。
恢复安卓之前不得格式化当前运行单系统的 `userdata`。

现有 `fastboot-flash` 和 `flash-rootfs` 是单系统工具，不能用于双系统部署：
前者写两个 boot 槽，后者针对 userdata。双系统只操作确定用于 Linux 的启动槽及 `linux` 分区。
用户已明确采用选择性重刷 Android 的维护方式，不需要原生 OTA 自动保护。
重刷前仍要审查包内脚本，独立根分区不会阻止脚本覆盖另一个系统的 boot 槽。

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
上述是早期基础检查。后续已完成扬声器实听、麦克风电平、笔压感和指纹录入/匹配/拒绝/删除，
详见 [外设验证](peripheral-validation.md)；桌面应用和长期使用仍未全量验收。
Android A 槽和 NixOS B 槽已完成双向切换测试，Android 的初始化状态与测试文件在切换后保留，
NixOS 也可在 Android 初始化后正常启动及 rebuild。测试使用设备原有 Android 16
`OS3.0.304.0.WNXCNXM` 系统内容，保留原 `super`，恢复同版本官方
`boot`、`dtbo`、`init_boot` 和 `vendor_boot`；这不等于重新刷入完整官方 ROM，
也不代表已验证所有第三方 ROM。双系统仍属于实验支持，后续 Android 按选择性重刷维护。

Recovery 同样分 A/B 槽：`fastboot reboot recovery` 会启动当前槽的 recovery。
切换后看到另一款 recovery 不代表原 recovery 被替换。可分别安装匹配 sheng 的 recovery，
无需因此修改 U-Boot。

## Android 维护策略：选择性重刷

用户明确不需要原生 OTA 自动保留双系统；接受按具体 ROM 包选择性重刷。
OTA 自动化不再列为移植待办，下面仅解释为何不能直接运行整包脚本或随意恢复一个槽。

当前没有实现“原生 Android OTA 后自动保留 NixOS 启动槽”。Android 从 A 槽更新时，
可能把更新写到非活动的 B 槽，包括覆盖 NixOS 的 `boot_b`、`dtbo_b`，随后切换到 B 槽。
`linux` 文件系统与启动槽是两回事：Linux 启动入口被覆盖，不等于根文件系统丢失。

不能把“OTA 后直接重刷 boot_b”当成通用升级方案。Virtual A/B 升级还涉及快照合并和
`super` 的逻辑分区布局；若升级后只有 Android B 槽可启动，直接覆盖 B 槽就会丢失这个入口。
应先针对具体升级包确认 Android A 槽可启动，再恢复 NixOS B 槽；必要时使用匹配版本的完整
Android 包选择性恢复 A 槽启动链及 `super`，保留 `linux` 和 Linux 启动槽。
这套 Android 升级迁移流程尚未实测，不应视为已支持的自动 OTA。

已知 A 槽安卓正常、仅 B 槽 Linux 启动文件需要恢复时，可以使用匹配当前系统的双系统
U-Boot 产物恢复入口，无需重刷 `linux`：

```sh
fastboot flash boot_b sheng-boot-dual.img
fastboot erase dtbo_b
fastboot set_active b
fastboot reboot
```

不要把单系统 `sheng-boot.img` 用在这里，它会读取 `userdata`。
不要为恢复 Linux 启动入口而清除 `userdata`、`metadata`、`linux` 或重建 GPT。

外设的实际测试范围及无桌面环境的笔配对方法见
[外设验证](peripheral-validation.md)。
