> 文中的原始 nixos-sheng SHA 对应当时的 CI 或实机记录。括号内的 SHA 对应改写后的 Git 历史。
> CI run ID、U-Boot 源 SHA 和镜像校验值仍采用原始记录。

# sheng EFI 探针

2026-11-13，B 槽设备通过 `fastboot boot` 临时加载第二版探针。
U-Boot 提交 `62edc2e44970d93bac1255d51c90c3f6a9ab6860`，
nixos-sheng 提交 `5fd1c2a`（改写后 `f2a0ce5d69e4`）。镜像 SHA256 为
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

探针源 b475d738c17，nixos-sheng `1bafec0`（改写后 `1cb9b2138584`），boot.img SHA256
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

U-Boot `cb343cefc72`，nixos-sheng `200555b`（改写后 `956cd752fef6`），ARM CI `43402463772`。
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

## 第 18 世代对照（Linux 7.3.4）

在修复后的 ext4 上，从第 18 世代 extlinux 条目生成 EFI 条目，复用其内核、
initrd、DTB 和面板参数。使用 CI 43402463772 的显式 DTB 探针，B 槽临时启动。
SSH 确认 EFI、第 18 世代及实际命令行，两个面板跳过参数均未启用。
内屏黑屏，面板状态读取 `ret=-61 val=0xaa`，UCM 服务失败。
还原条目和 DTB 后重启，确认 extlinux 和 SSH 恢复，面板读取 `ret=0 val=0x9e`。

下一轮仅在 systemd-boot 探测路径的 EFI ExitBootServices 调用 sheng 的
`board_preboot_os()`，复用 extlinux 的显示清理，验证黑屏是否来自显示交接。

## EFI 显示交接复用 extlinux 清理

U-Boot `5d7445dfb05`，nixos-sheng `80c172e`（改写后 `a159eb1b40ea`），ARM CI `43449167013`。
镜像 SHA256 为 `7b3069a632fc382426601847a50c43a2e10f1023d208310a2b939233ee392bc5`。
B 槽临时启动，第 18 世代通过 EFI 进入桌面，用户确认内屏可见。
面板读取恢复为 `ret=0 val=0x9e`。这组对照支持复用 sheng 显示清理可恢复内屏。
音频声卡已枚举，但 UCM 导入仍返回 -2，同一时间内核记录 qcom-apm 命令超时。
测试后还原 EFI 条目和探测 DTB，再重启回 extlinux。

同一第 18 世代的两份持久日志显示，EFI 与 extlinux 均成功启动 ADSP，
且均出现 APM opcode `1001021` 超时及相同 SoundWire 端口告警。
EFI 的 UCM 在 12.872 秒启动并返回 -2，extlinux 在 13.411 秒启动并成功完成。
因此上述内核告警不能区分两条路径。下一轮应保留 EFI 会话，在声卡完成枚举后
用同一环境重试 UCM，并跟踪返回 ENOENT 的实际文件或 ALSA 控件。

## 音频修复与使用范围

EFI 启动下 ALSA 按声卡长名称查找 UCM 配置。增加长名称别名后，
HiFi、Speaker 和 Mic3 初始化成功，WirePlumber 枚举内置扬声器和麦克风。
第 18 世代的 PipeWire 测试音已由用户确认从内置扬声器听到。

正式安装镜像仍使用 extlinux。已有设备可以通过原有 NixOS 世代流程更新。
在 Actions 手动运行 build-dual 并启用 efi_probe 可构建单独的实验镜像，
供双系统设备使用 fastboot boot 临时启动。合并代码不会改写设备的 boot 分区。
永久采用 EFI 还需要独立验证 ESP 布局、世代更新和救援。

## 单系统探针

单系统用户在 Actions 手动运行 `build` 并启用 `efi_probe`，
下载 `sheng-efi-probe-single`。它读取 `userdata` 上的 NixOS 文件；
双系统探针仍由 `build-dual` 生成并读取 `linux`。
单系统 TTY 已实机验证。请使用已有 NixOS ext4 的单系统设备进行临时启动，
双系统设备的 Android `userdata` 不适用于此测试。

实测使用单系统探针 CI `43453660713` 和 TTY 根镜像 CI `43454075043`。
探针 SHA256 为 `29c4a0b8b8013ee43d08bc192fac8d955caa7e7fa43ea27676b03c503397f13e`。
在 B 槽临时启动，串口确认 EFI、`userdata` 根分区和 `7.3.4-sm8550`。
用户照片确认内屏显示 tty1，面板读取 `ret=0 val=0x9e`，UCM 服务为 active。
仍有音频驱动告警，单系统扬声器与录音未实测。普通重启后经串口确认回到
`linux` 上的原第 18 世代 extlinux。测试 NixOS 保留在 `userdata`。

## 下一轮：NixOS 世代安装与回退

先保留现有 extlinux 救援入口。用 GitHub ARM CI 构建单系统 EFI 探针和候选闭包，
沿用已实测的 U-Boot 从 userdata ext4 读取 systemd-boot 的路径。测试条目与文件单独暂存，
备份现有探针文件后，通过 ABL fastboot 临时启动。核对两个条目的内核、initrd、DTB、
根 PARTLABEL 与 init 路径，依次启动新旧世代，最后普通重启确认恢复 extlinux。

标准 NixOS systemd-boot 安装器可先在 ARM CI 的 GPT/FAT 镜像中验证。
实机 ext4 探针验证的是世代条目与启动回退，正式 ESP 布局仍待单独确定。

单系统探针和 TTY 根镜像的实际 CI 源均为
`ec6c3b439d5be30821c8150a196c5cb2a44dabf8`，改写后对应
`0975f4748d5aa1c3624032ec058aaad8075f9829`。

### 2026-11-14：测试 ESP 安装预检

SSH 确认平板从 B 槽以 extlinux 启动第 18 世代，tmpfs 根的 ext4 后端
PARTLABEL 为 `linux`。内置存储未发现 ESP 类型的分区。

在平板的临时文件中建立 256 MiB GPT 镜像，经 loop 挂载 FAT32 ESP。
systemd 262 的 `bootctl --no-variables install` 成功安装 ARM64 fallback 文件，
`bootctl is-installed` 返回 `yes`。`EFI/BOOT/BOOTAA64.EFI` SHA256 为
`76a5bba20322d4929f35c608199f21f80317ae006805315ca215382cdef4c75b`。
卸载后删除了临时镜像。下一项是在现有 userdata ext4 探针上验证两个世代的启动和回退。

### 2026-11-14：单系统探针复测

[ARM CI 43509366497](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43509366497)
从 `5022490a33cdcff8d074829fd7ec5a46238d2e67` 构建成功。下载产物的
boot.img SHA256 与 43453660713 的已验镜像一致，实机临时加载了后者。
B 槽 ABL fastboot 接受镜像，USB 串口确认 EFI、`root=PARTLABEL=userdata`、
`sheng.efi_probe=single` 和 UCM active。实测系统为
`/nix/store/w1fyfyk9dgjghlfgri3kk5fmhmlk6cf4-nixos-system-sheng-26.11.20261103.1d06008`。
用户确认内屏进入 tty，期间有日志输出，未采集这些日志的具体内容。
从串口正常重启后，确认回到 `linux` 的 extlinux 第 18 世代。
本轮复测覆盖单系统启动与恢复，`userdata` 目前只有一个测试世代。

照片中的四条日志为 `wcd938x_codec audio-codec: Impedance detect ramp error, c1=3, x1=0x0`。
同一次复测返回 extlinux 第 18 世代后，`7.3.4-sm8550` 的当次内核日志也记录了四条
相同报错，UCM 仍为 active。该报错出现在两种启动路径；单系统内置扬声器、
录音和耳机功能仍需实测。

### 自动启动探针首轮

[ARM CI 43512681130](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43512681130)
从 `5a9702d2f0b578f566434461e6f68f42141737de` 构建成功。
临时 boot.img SHA256 为 `cbdce45ececdb8db5729dee082261f3631e0c98d33160c79429e225cd81c5483`。
ABL B 槽接受 `fastboot boot`，之后主机未发现 fastboot 或 Linux ACM，
原 SSH 地址也未恢复。尚无证据确认 systemd-boot 或 NixOS 已运行。
下次先记录屏幕状态并确认能恢复 extlinux，再对照原菜单路径与直接执行 bootcmd
的差异。此轮未刷写启动分区。

用户随后确认内屏已进入 root TTY，并看到数条错误日志。首轮启动条目默认仍为
`sheng-single.conf`（原 root 世代），普通用户候选为独立条目
`sheng-single-tty.conf`。本轮没有串口或 SSH 证据，EFI 状态和实际条目待从本机核对。

### 自动启动普通用户候选

在 extlinux 第 18 世代通过 SSH 将 `userdata` 上的 systemd-boot 默认条目切为
`sheng-single-tty.conf`，保留旧条目及 loader.conf 备份。使用同一 CI 43512681130
探针从 B 槽 ABL 临时启动，无需菜单输入。串口确认 EFI、根分区 `userdata`，
启动系统为 `/nix/store/1gxbjwz5qm5s6s442fdvj1slcgszviiq-nixos-system-sheng-26.11.20261103.1d06008`
（ARM CI 43510277632，源码 `d52c1f003c91845f95ed3748fd4a45b70b0bc4b6`）。
`loginctl` 确认 tty1 和 ttyGS0 均自动登录 UID 1000 的 `nixos`，UCM 最终 active。
普通用户的串口重启需要管理员认证。通过本地串口发起重启，
随后经串口确认恢复到 linux 分区的 extlinux 第 18 世代。
