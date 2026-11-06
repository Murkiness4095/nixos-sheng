# flake-parts 个人配置样板

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
