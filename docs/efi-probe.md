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
