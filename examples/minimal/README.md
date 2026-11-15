# sheng 最小个人配置

[English](./README.en.md) · 简体中文

两个模板目标均使用 EFI。已有 extlinux 的设备先完成下文的 EFI 迁移，再运行日常更新命令。

## 个人配置与更新

复制本目录到设备的 `/etc/nixos` 或个人 nix-config 仓库。此样板为命令行系统，硬件、根分区和启动配置由 nixos-sheng 提供；不会自动安装桌面。

样板随附锁文件，固定到已验证的硬件仓库版本；保留锁文件时，硬件功能基线与同版本 CI 一致。`shengSystem` 导入完整硬件模块，并未精简固件或厂商服务。个人配置只增加设置，不需要重新逐项启用这些功能。

首次构建（保留随附的 `flake.lock`）：

```sh
cd /etc/nixos
sudo nixos-rebuild build --flake .#sheng
sudo nixos-rebuild boot --flake .#sheng
sudo reboot
```

若在 Git 仓库内，新文件需先 `git add flake.nix configuration.nix`，Nix 才会将其包含到 flake 源中。检查 `bootctl list` 和 systemd-boot 世代菜单，保留可启动的旧世代，不要在新内核验收前执行删除旧世代的 GC。

更新硬件配置输入：

```sh
nix flake update nixos-sheng
sudo nixos-rebuild boot --flake .#sheng
sudo reboot
```

内核由输入仓库的包定义固定；更新锁文件不等于指定任意新内核版本。先在硬件仓库完成内核适配，再更新本配置的输入。

CI 和本机 rebuild 都可以构建系统。普通内核、固件、服务更新通过 rebuild 部署；U-Boot 自身仍需单独更新 Android boot 分区。

## 可选 tmpfs

默认是传统 ext4 根目录，启用 EFI 所需的 initrd，tmpfs 按需开启。需要时参阅
[initrd/tmpfs 说明](../../docs/initrd-tmpfs.md) 和 [preservation 样板](../tmpfs-root.nix)。
tmpfs 下仍需正确选择 `linux` 或 `userdata`，用于定位持久化 ext4。
tmpfs 默认不绑定整个 `/home`；preservation 样板通过调用者提供的 `user` 按目录保留数据。
如需完整 home，显式设置 `persistHome = true`。用户名、凭据和应用数据策略
由个人配置决定，样板不保证覆盖所有应用。不要直接复用 x86 的整盘 disko 格式化配置。

## EFI 启动

两个目标都使用 systemd-boot。默认目标 `.#sheng` 用于单系统，
根分区为 `userdata`。双系统选 `.#sheng-dual-efi`，根分区为 `linux`。
不要在共享主机模块中另行覆盖根分区标签。主机名仍为 `sheng`，
因此更新时请显式指定所选目标。

首次切换时，先按 [EFI 安装与迁移指南](../../docs/efi-install.md) 准备
`sheng-esp` 和对应的 U-Boot，再安装候选世代。例如双系统运行：

```sh
sudo nix run github:Murkiness4095/nixos-sheng#sheng-efi-migrate -- --flake "$PWD#sheng-dual-efi"
```

EFI 世代启动并自动挂载 `/efi` 后，日常更新用
`sudo nixos-rebuild boot --flake .#sheng-dual-efi`。单系统将命令中的
`sheng-dual-efi` 换成 `sheng`。
