# sheng 最小个人配置

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
