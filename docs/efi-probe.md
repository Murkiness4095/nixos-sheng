# sheng EFI 探针

2026-11-13，B 槽设备通过 `fastboot boot` 临时加载第二版探针。
U-Boot 提交 `62edc2e44970d93bac1255d51c90c3f6a9ab6860`，
nixos-sheng 提交 `5fd1c2a`。镜像 SHA256 为
`961934daa03a858bda4ef838a0d8cb028bc50d868613c33a0fe1e018dcc119ee`。

第一版把两条 bootcmd 写进原始环境，正常菜单覆盖了测试入口。
第二版只保留一条 bootcmd，菜单倒计时为 10 秒。本机交叉构建成功。

用户选中 Test EFI hello 后，屏幕显示 Hello, world!、UEFI 2.11、
Das U-Boot 和 Have device tree，程序随后返回 U-Boot 提示符。
该测试使用内嵌 EFI 程序，启动设备显示为 MemoryMapped。
本轮只执行临时启动，未刷写分区。

下一步验证从现有存储读取 systemd-boot EFI 文件，并验证它能加载当前世代
的内核、initrd 和设备树。正式 ESP 布局待定，现有分区保留。

## systemd-boot 实机结果

探针源 b475d738c17，nixos-sheng 1bafec0，boot.img SHA256
`53cbc918e712db9c81a7e91254b0c76bab8e2060793be423c8e120b6cafb3781`。
通过 fastboot boot 临时加载。systemd-boot 从现有 linux ext4 读取测试条目，
加载当前世代的内核、initrd 和 DTB。SSH 验证了 /sys/firmware/efi 和
sheng.efi_probe=1，原 ext4 后端已挂载。用户报告内屏黑屏。DRM DSI
显示 connected/enabled，背光有非零读数。声卡已枚举，但 sheng-alsa-ucm
导入配置失败，重试仍失败。显示和音频原因分别待定位。

采集日志后通过 SSH 重启，已验证回到 extlinux，失败服务数为零。
临时 EFI 测试文件保留供复测，启动分区及分区表未写入。

## efifb 对照

同一探针和世代仅增加 `video=efifb:off`。SSH 确认参数生效且无 efifb
注册日志。用户观察到闪烁后仍黑屏。面板状态读取仍为 `ret=-61`，
extlinux 对照为 `ret=0 val=0x9e`。音频 UCM 失败也仍存在。
关闭 efifb 不足以恢复显示。采集日志后移除临时参数，重启恢复。

## 显式传入 U-Boot DTB

U-Boot `cb343cefc72`，nixos-sheng `200555b`，ARM CI `43402463772`。
boot.img SHA256 为
`f03a40e368d3f96b6c4993dab45b8c8afaba4a43737ccfdc4a4f0a74b19a7339`。
B 槽用 fastboot boot 临时启动，未刷写。SSH 确认 EFI 与原世代
`ndzcvh286al8vbfmmxf0ayc8srzzyxcv-nixos-system-sheng-26.11.20261103.1d06008`。
内屏闪烁后黑屏，UCM 服务仍失败。实际内核命令行额外带有
`panel_novatek_nt36532e.noinit=1` 与 `panel_novatek_nt36532e.noreset=1`，
而临时加载器条目的 options 行不含这两项。因此本次无法单独归因于 DTB；
面板日志为 `noinit=1 noreset=1 ret=-61 val=0xaa`。

复查发现，实际条目是分区根目录的 `/loader/entries/sheng-efi-probe.conf`
（从 NixOS 访问为 `/sysroot-storage/loader/entries/sheng-efi-probe.conf`）。
额外参数来自该旧条目。`/boot/loader/entries` 下的副本没有被读取。
在实际条目中移除两个面板参数并加入 `sheng.efi_control=explicit-dtb` 后，
用同一镜像再次临时启动。用户仍观察到闪烁后黑屏。主机看到 USB 串口节点，
但 SSH 和串口未返回运行时命令行，故未确认标记是否进入内核。
