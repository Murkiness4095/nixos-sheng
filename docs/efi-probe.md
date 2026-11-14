> 文中的原始 nixos-sheng SHA 对应当时的 CI 或实机记录。括号内的 SHA 对应改写后的 Git 历史。
> CI run ID、U-Boot 源 SHA 和镜像校验值仍采用原始记录。

# sheng EFI 探针

## Actions 里选哪个
自动启动探针供无人值守复测使用，维护者可在 ARM Linux 上构建 `nix build .#u-boot-efi-auto-single`。

在 GitHub Actions 打开 **EFI experiments**，手动运行时按下表选择 `task`。

| 选项 | 用途 | 产物 |
| --- | --- | --- |
| `single` | 单系统 NixOS（根分区 `userdata`）。临时启动后，在 U-Boot 菜单选 **Test systemd-boot**。 | `sheng-efi-probe-single` |
| `dual` | Android/NixOS 双系统（NixOS 根分区 `linux`）。临时启动后，在 U-Boot 菜单选 **Test systemd-boot**。 | `sheng-efi-probe-dual` |
| `generations` | CI 在 x86 NixOS VM 中用虚拟 ESP 验证 systemd-boot 世代更新、重启和回滚。 | 查看 CI 日志，无平板镜像 |

前两项要求目标分区已有 NixOS 和准备好的 EFI 文件及条目，下载的
`boot.img` 用于 ABL 下的 `fastboot boot` 临时测试。正式安装镜像仍由
`build`（单系统）或 `build-dual`（双系统）生成。

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
在 Actions 手动运行 `EFI experiments` 并选择 `dual` 可构建单独的实验镜像，
供双系统设备使用 fastboot boot 临时启动。合并代码不会改写设备的 boot 分区。
永久采用 EFI 还需要独立验证 ESP 布局、世代更新和救援。

## 单系统探针

单系统用户在 Actions 手动运行 `EFI experiments` 并选择 `single`，
下载 `sheng-efi-probe-single`。它读取 `userdata` 上的 NixOS 文件；
双系统探针由同一工作流的 `dual` 任务生成并读取 `linux`。
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

标准 NixOS systemd-boot 安装器已在 [x86 VM CI 43563738497](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43563738497) 验证两代更新、重启和回滚。
[ARM CI 43564930147](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43564930147) 用于构建 sheng 专用候选闭包。
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

## 分支维护

NixOS 的临时自动探针由 PR #13 集成，保留独立的探针构建选项。
U-Boot 仓库的 `xiaomi-sheng` 是日常 extlinux 来源；EFI 试验使用
`codex/sheng-efi-display-control` 上已实测的固定 SHA
`5d7445dfb0551aec8a3e2ad23367cabe5695351a`。较早的
`codex/sheng-efi-probe` 留作对照。后续准备正式集成时，从
`xiaomi-sheng` 提取所需改动并独立验证 extlinux 和 EFI，
避免把历史探针菜单与临时调试改动一并带入日常分支。

旧 EFI 条目仍保留在 `userdata`。下一次用相同临时探针选择
`sheng-single.conf`，从运行时核对 EFI、根 PARTLABEL 和旧系统路径，
再重启恢复 extlinux。测试前先确认主机 USB 可用。

### 单系统旧 EFI 条目与串口恢复

用同一自动探针（ARM CI 43512681130）把默认条目切回
`sheng-single.conf`，经 B 槽 ABL 临时启动。USB 串口确认 EFI、根
PARTLABEL `userdata`、`root` 自动登录及 UCM active。启动系统为
`/nix/store/w1fyfyk9dgjghlfgri3kk5fmhmlk6cf4-nixos-system-sheng-26.11.20261103.1d06008`。
正常重启后，SSH 确认回到 `linux` 上的 extlinux 第 18 世代，USB gadget
为 configured，主机重新生成 `/dev/ttyACM0`。候选和旧 EFI 条目均已实测，
切换时改的是探针的 loader.conf 默认条目。标准 NixOS systemd-boot
世代安装流程仍待验证。

此前 extlinux 重启期间，主机记录了一次 USB 断开。随后主机内核已重新枚举
`ttyACM0`，但一度缺少对应的字符设备节点。按 sysfs 中的设备号临时补建节点后，
串口可读。此后正常启动时恢复了自动创建节点。磁吸键盘套的影响未做单变量对照。

### sheng ARM 候选的标准安装器预检

ARM CI 43564930147（`5b794fbdcc6f5efdf6345a1babbd3a7b64020227`）构建的系统
为 `/nix/store/36x6gg4wflr0rxbmrk28vr5w85a8fmq1-nixos-system-sheng-26.11.20261103.1d06008`。
闭包 SHA256 为 `a79dcced47e588fc853259b85fc3710dac9a76e18c05c580ec9b567f32e7d11a`。
在平板 extlinux 第 18 世代运行期间，用独立挂载命名空间、临时系统 profile
和 512 MiB GPT/FAT32 镜像执行候选的 `switch-to-configuration boot`。
首次安装生成了 ARM64 fallback、第一世代条目、内核、initrd 和 DTB。再次执行
boot 更新成功，并报告 EFI 二进制已是同一版本。条目使用 `root=fstab`，
下一次启动前需核对 initrd 的根分区配置。

| 文件 | SHA256 |
| --- | --- |
| Kernel | `87eb903bcbd374c9a93200ab8f6d2df33fa41374e27a59961f8f12380d990325` |
| Initrd | `74e57528c4c76bf70b051709b8f09e2da2f71aede3758896638f298eb316de9e` |
| DTB | `6882a55608692133d36555b6fc241b03a20528556fed57faa2678a7b9fe3d2bc` |
| BOOTAA64.EFI | `76a5bba20322d4929f35c608199f21f80317ae006805315ca215382cdef4c75b` |

临时镜像已卸载和删除。此轮验证的是 ARM 候选生成和更新启动文件，
下一步才是通过临时探针实际启动这些条目。

### 标准安装器生成条目的单系统启动

同一 ARM 候选的 fstab 指向 `/dev/disk/by-partlabel/userdata`。将标准安装器
生成的内核、initrd 和 DTB 复制到测试根分区并逐个比较字节。条目保留
`root=fstab`，增加探针标记并屏蔽临时启动的槽位成功服务。
使用 ARM CI 43512681130 的自动探针从 B 槽 ABL 临时启动。
串口确认 EFI、`sheng.efi_probe=generated`、根 PARTLABEL `userdata`、
上述候选系统路径及 UCM active。正常重启后经串口确认回到
`linux` 上的 extlinux 第 18 世代。SSH 恢复后把测试默认条目还原为
`sheng-single.conf`。此轮证明生成条目可上机启动，持久 ESP 与真机标准世代更新仍待验收。

### 平板上的两代安装器更新与回滚

[ARM CI 43568095098](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43568095098)
从 `20c2873b977b8d133512198a0932821cb3a8427f` 导出两代闭包，
SHA256 为 `7fd3c089988f00e36a2c4837edd9e3403cfc1dd59851af77804fe32bb05f9983`。
第一代为前述 `36x6gg4wflr0rxbmrk28vr5w85a8fmq1` 系统，第二代为
`/nix/store/6vnwrphxifgkx8j50xyx2rd3q93bq8bs-nixos-system-sheng-efi-generation-2`。
两代使用相同 kernel、initrd、DTB，校验值同上。在平板 extlinux 下，
用独立 profile 和临时 FAT ESP 执行 `switch-to-configuration boot`，
确认第二代成为默认。执行 `nix-env --rollback` 后再次运行第一代安装器，
确认 ESP 默认条目恢复到第一代。临时 ESP 测试未重启两代系统。
主存储 LUN 无未分配空间，持久 ESP 布局仍待确定。

### 第二代 ARM 候选临时启动

导入 CI 43568095098 的第二代闭包到 `userdata` 的独立 Nix store。
确认 kernel、initrd、DTB 和内核参数与第一代一致后，复用已验证的 EFI 文件，
新增测试条目并改用第二代 init 路径。同一自动探针从 B 槽 ABL 临时启动后，
串口确认 EFI、`userdata` 和 `6vnwrphxifgkx8j50xyx2rd3q93bq8bs` 系统。
UCM 在取样时仍为 activating。随后串口确认恢复 `linux` 上的 extlinux
第 18 世代，SSH 恢复后将测试默认条目还原为 `sheng-single.conf`。
两代候选均已通过临时 EFI 启动。隔离 ESP 的安装器更新与回滚结果见上一节，
持久 ESP 部署仍待确定。

### 持久 ESP 布局预检

2026-11-14 从 extlinux 第 18 世代只读复核。主 UFS LUN 的逻辑扇区为
4096 字节，现有 GPT 无可用的未分配区间。测试机的 `userdata` 位于
`linux` 前面，`linux` 延伸到主 LUN 的 GPT 尾部。磁盘上现有的 FAT 分区
属于厂商用途，保留原用途。内置 ESP 目前没有直接可用的位置。

若为双系统新增内置 ESP，布局上可以从末尾的 `linux` 划出空间，
保留分区起点和 Android 区间。这要求先离线备份并验证恢复，再缩小 ext4，
最后才调整 GPT 中的分区终点。单系统须重新读取末尾分区及实际空隙，
以该设备的现场布局为准。ESP 容量应按计划保留的世代、实际 kernel 和
initrd 尺寸以及更新所需余量计算。

下一项可逆对照是让同一临时 U-Boot 在独立测试磁盘上明确加载
`EFI/BOOT/BOOTAA64.EFI`，再核对 U-Boot 传入的 DTB、显示清理及
systemd-boot 的世代识别。已有 ext4 探针继续用于真机验证。
本次只读预检未改变文件系统或分区表。

候选的内核为 43,633,152 字节，initrd 为 22,248,985 字节，DTB 为
186,193 字节。一套独立启动文件合计约 63 MiB。systemd-boot 的两份
EFI 文件合计约 346 KiB。按三代加一套写入余量估算约 252 MiB，
实验采用 512 MiB，给 FAT 开销和后续文件增长留出空间。
当前两代共享内核、initrd 和 DTB，不能用这次的实际占用推算跨内核更新的上限。

### 4 KiB 扇区 ESP 布局演练

在平板上用临时 1 GiB 文件模拟 4096 字节逻辑扇区的 GPT 磁盘。
离线缩小测试 ext4 后，从尾部划出约 511 MiB 的 FAT32 ESP。
原 ext4 分区起点和 PARTUUID 保持一致，`e2fsck -fn` 通过，
重新挂载后测试文件 SHA256 与缩容前一致。
`bootctl --no-variables install` 成功安装 ARM64 fallback，
其 SHA256 仍为 `76a5bba20322d4929f35c608199f21f80317ae006805315ca215382cdef4c75b`。
临时镜像已清理。此轮覆盖分区几何、文件系统及安装器，真实 UFS 分区没有调整，
仍需验证 U-Boot 能从内置 FAT ESP 加载 fallback 并交接 DTB。

### RAM FAT 上的 ARM64 fallback 实测

首轮 ARM CI 43570919587 的脚本调用了 blkmap，但镜像缺少该命令。
补上 `CONFIG_BLKMAP` 并在 CI 检查命令后，
[43571479431](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43571479431)
构建成功。源码 `034559021da74476feab326b912b42fc628bfeb9`，
boot.img SHA256 `4f672d7c8af1c17f9ca17cdc3b032e9f7bed9d6342ee5ab401eac4acccafb2f7`。
8 MiB FAT16 镜像 SHA256 为
`b2d743b73633189dd3aacb9e43db939f84da3d76923431490743986d61b4e2cf`。

B 槽 ABL 临时启动后，用户看到 `sheng FAT probe - systemd-boot reached`。
这确认 U-Boot 从 RAM 映射的 FAT 文件系统加载 ARM64 fallback，
systemd-boot 可以读取同一 FAT 上的条目。此测试只含菜单，未加载 Linux，
内置 UFS ESP 和完整 DTB 交接仍待实测。

### RAM FAT32 完整启动

ARM CI [43572104110](https://github.com/Murkiness4095/nixos-sheng/actions/runs/43572104110)
使用源码 `bf03f461d16795031116aef3d62383e6d2ec9ab9`。
探针 boot.img SHA256 为 `790b74fd6c3223f9da6cd4f74cf30fe69165ad7449b7bc54ef6de737b7f10065`，
128 MiB FAT32 镜像 SHA256 为 `55fe428f68ee5a3f93875a135f281bc6eb59523ad59e7173628851bbcb25da0a`。
此前的菜单测试结束后，SSH 确认恢复 extlinux 第 18 世代。

从 B 槽经 ABL 临时加载探针，U-Boot 从 RAM 映射 FAT32 加载 ARM64 fallback。
systemd-boot 从同一 FAT 读取内核、initrd 和 DTB，自动启动第一代 ARM 候选。
USB 串口确认 EFI、根 PARTLABEL `userdata`、系统路径前缀 `36x6gg4wflr0`、
内核 `7.3.4-sm8550`、DT 型号 Xiaomi Pad 6S Pro 12.4 和 UCM active。
此轮未改真实 GPT 或刷写启动分区；内置 UFS ESP 上的持久加载仍待实测。
通过串口发起正常重启后，再次通过串口确认恢复到
`linux` 后端的 extlinux 第 18 世代。
