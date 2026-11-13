# flake-parts 个人配置样板

[English](./README.en.md) · 简体中文

## 先选择单系统或双系统

**当前构造器默认单系统，根分区为 `userdata`。** 双系统个人配置可选一种方式：

- 保留 `lib.shengSystem`，在 `node-sheng` 设置 `sheng.rootfs.partlabel = "linux";`。
- 用以下定义替换原来的构造器，继承仓库双系统配置，不再重复声明分区：

  ```nix
  flake.nixosConfigurations.sheng =
    inputs.nixos-sheng.nixosConfigurations.sheng-dual.extendModules {
      modules = [ self.nixosModules.node-sheng ];
    };
  ```

两种定义不能同时保留。继承方式会带入上游 `networking.hostName = "sheng-dual"`，
样板已通过 `lib.mkForce "sheng"` 覆盖；不需要重新导入硬件模块。
输出名和主机名不会自动选择分区。旧锁文件使用继承接口前先更新 `nixos-sheng` 输入。

## 模块组织

`modules/sheng.nix` 使用 `flake.nixosConfigurations` / `flake.nixosModules.node-sheng`，可以按现有 x86 配置的写法组织主机。本目录的 `modules/` 中每个文件都是 flake-parts 模块；入口用 import-tree 自动导入。

`shengSystem` 已导入完整板级配置并配置硬件 overlay、允许专用固件包，默认使用硬件仓库锁定的 nixpkgs。不要仅把 `nixosModules.default` 塞进普通 `nixosSystem` 就假设两者等价：普通调用还需正确接好包集合和模块参数。

把你自己的 `self.nixosModules.base`、`desktop`、`pipewire` 等可用于 aarch64 的模块加入主机的 imports；无需重复声明内核、DTB、userdata 根分区或启动安装器。x86 主机的 NVIDIA、asusctl、systemd-boot、磁盘 UUID 以及 linuxPackages_latest 设置不要直接带入 sheng。共享模块中如果包含这些设置，应先拆成对应主机的设置。

## hardware-configuration.nix 在哪里？

这个文件名不是 NixOS 的强制约定。板级职责分布在输入仓库的 `modules/hardware.nix`、`firmware.nix`、`extlinux.nix` 等模块，由 `shengSystem` 一起导入。

普通 PC 的自动生成文件记录扫描到的硬件及挂载点；sheng 的专用内核、固件服务和 U-Boot 启动约定则由维护好的板级模块提供。可以另外保留个人 `hardware-configuration.nix` 记录机器特有的设置，但不需要用扫描生成的文件替换板级配置，也不要把 x86 的硬件文件导入平板。

## 构建

保留样板附带的锁文件，用同一版本的硬件仓库保持与 CI 相同的功能基线：

```sh
git add flake.nix flake.lock modules
sudo nixos-rebuild build --flake .#sheng
sudo nixos-rebuild boot --flake .#sheng
sudo reboot
```

这里的最小样板与当前基础 CI 一样是命令行系统；桌面来自你自己导入的桌面模块。共享 x86/ARM flake 时，可以继续让 x86 使用个人 nixpkgs，sheng 先使用硬件输入自己的锁定版本；统一 nixpkgs 版本是另一项需要验证的升级。

## 可选 tmpfs 与持久化边界

默认仍是 ext4，不启用 tmpfs。参考 [专项说明](../../docs/initrd-tmpfs.md) 和
[NixOS 样板](../tmpfs-root.nix)；后者是普通 NixOS 模块，不是 flake-parts 模块，
不要直接放进自动扫描的 `modules/`。应由你的 `flake.nixosModules` 封装或显式导入。

tmpfs 默认让 home 易失，样板按调用者提供的 `user` 保留选定目录，不绑定整个
`/var` 或 `/root`。`user` 必须通过个人模块参数或显式调用传入，不是板级默认用户名。
如需兼容初版的完整 home 模式，设置 `sheng.rootfs.tmpfsRoot.persistHome = true;`。
用户身份和应用数据策略属于用户端配置；样板不是无遗漏的通用清单。
