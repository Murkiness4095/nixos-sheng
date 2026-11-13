# sheng 最小个人配置

[English](./README.en.md) · 简体中文

## 先选择单系统或双系统

**本样板默认单系统：`lib.shengSystem` 使用 `userdata`。** 它不会因为设备已有 Android、
主机名或输出名称改变而自动选择双系统。现有双系统设备请在构建前选择以下一种方式：

1. 保留构造器，在 `configuration.nix` 设置 `sheng.rootfs.partlabel = "linux";`。
2. 将 `flake.nix` 中的系统定义替换为继承仓库双系统配置：

   ```nix
   nixosConfigurations.sheng =
     nixos-sheng.nixosConfigurations.sheng-dual.extendModules {
       modules = [ ./configuration.nix ];
     };
   ```

第二种方式已继承 `linux` 根分区，无需重复设置，也无需再次导入板级模块。
仓库双系统配置明确设置主机名为 `sheng-dual`；本样板用 `lib.mkForce "sheng"` 覆盖它，
因此更新命令仍为 `#sheng`。输出名、主机名、根分区和 Android 启动槽是不同概念。
随附锁文件需包含双系统配置；旧 checkout 使用继承方式前先 `nix flake update nixos-sheng`。

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

若在 Git 仓库内，新文件需先 `git add flake.nix configuration.nix`，Nix 才会将其包含到 flake 源中。检查 `/boot/extlinux/extlinux.conf` 和 U-Boot 世代菜单，保留可启动的旧世代，不要在新内核验收前执行删除旧世代的 GC。

更新硬件配置输入：

```sh
nix flake update nixos-sheng
sudo nixos-rebuild boot --flake .#sheng
sudo reboot
```

内核由输入仓库的包定义固定；更新锁文件不等于指定任意新内核版本。先在硬件仓库完成内核适配，再更新本配置的输入。

CI 和本机 rebuild 都可以构建系统。普通内核、固件、服务更新通过 rebuild 部署；U-Boot 自身仍需单独更新 Android boot 分区。

## 可选 tmpfs

默认是传统 ext4 根目录，不启用 initrd 或 tmpfs。需要时参阅
[initrd/tmpfs 说明](../../docs/initrd-tmpfs.md) 和 [preservation 样板](../tmpfs-root.nix)。
tmpfs 下仍需正确选择 `linux` 或 `userdata`，用于定位持久化 ext4。
tmpfs 默认不绑定整个 `/home`；preservation 样板通过调用者提供的 `user` 按目录保留数据。
如需完整 home，显式设置 `persistHome = true`。用户名、凭据和应用数据策略
由个人配置决定，样板不保证覆盖所有应用。不要直接复用 x86 的整盘 disko 格式化配置。
