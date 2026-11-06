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
